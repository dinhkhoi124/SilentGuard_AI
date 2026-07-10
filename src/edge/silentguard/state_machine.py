from __future__ import annotations

import uuid
from dataclasses import dataclass

from .config import FallConfig
from .types import FallIncident, FallState, PoseObservation


@dataclass(slots=True)
class TrackState:
    state: FallState = FallState.UPRIGHT
    state_since: float = 0.0
    last_seen: float = 0.0
    lying_since: float | None = None
    last_lying_at: float | None = None
    recovery_since: float | None = None
    peak_velocity: float = 0.0
    peak_angle: float = 0.0
    incident_id: str | None = None


class FallStateMachine:
    """Per-track temporal fall classifier with one incident per fall lifecycle."""

    def __init__(self, config: FallConfig):
        self.config = config
        self.tracks: dict[int, TrackState] = {}

    def update(self, observation: PoseObservation) -> FallIncident | None:
        now = observation.timestamp
        track = self.tracks.setdefault(
            observation.track_id,
            TrackState(state_since=now, last_seen=now),
        )
        track.last_seen = now
        track.peak_velocity = max(track.peak_velocity, observation.downward_velocity_bh_s)
        track.peak_angle = max(track.peak_angle, observation.torso_angle_deg)

        if track.state is FallState.UPRIGHT:
            if observation.downward_velocity_bh_s >= self.config.descending_velocity_bh_s:
                self._transition(track, FallState.DESCENDING, now)
                track.peak_velocity = observation.downward_velocity_bh_s
                track.peak_angle = observation.torso_angle_deg

        elif track.state is FallState.DESCENDING:
            elapsed = now - track.state_since
            if observation.torso_angle_deg >= self.config.lying_torso_angle_deg:
                self._transition(track, FallState.LYING_CONFIRMING, now)
                track.lying_since = now
                track.last_lying_at = now
            elif elapsed > self.config.transition_limit_sec:
                self._reset(track, now)

        elif track.state is FallState.LYING_CONFIRMING:
            if observation.torso_angle_deg >= self.config.lying_torso_angle_deg:
                track.last_lying_at = now
            recent_lying = (
                track.last_lying_at is not None
                and now - track.last_lying_at <= self.config.lying_gap_tolerance_sec
            )
            if observation.torso_angle_deg < self.config.recovery_angle_deg and not recent_lying:
                self._reset(track, now)
            elif track.lying_since is not None and recent_lying:
                lying_duration = now - track.lying_since
                if lying_duration >= self.config.lying_confirmation_sec:
                    self._transition(track, FallState.FALL_CONFIRMED, now)
                    track.incident_id = track.incident_id or self._new_event_id(now)
                    return FallIncident(
                        event_id=track.incident_id,
                        track_id=observation.track_id,
                        detected_at=now,
                        confidence=self._fall_score(track, observation, lying_duration),
                        lying_duration_sec=lying_duration,
                    )

        elif track.state is FallState.FALL_CONFIRMED:
            self._transition(track, FallState.LYING, now)

        elif track.state is FallState.LYING:
            if observation.torso_angle_deg <= self.config.recovery_angle_deg:
                track.recovery_since = track.recovery_since or now
                if now - track.recovery_since >= self.config.recovery_upright_sec:
                    self._transition(track, FallState.RECOVERED, now)
            else:
                track.recovery_since = None

        elif track.state is FallState.RECOVERED:
            self._reset(track, now)

        return None

    def expire(self, now: float) -> list[int]:
        expired = [
            track_id
            for track_id, track in self.tracks.items()
            if now - track.last_seen > self.config.track_expiry_sec
        ]
        for track_id in expired:
            del self.tracks[track_id]
        return expired

    def state_for(self, track_id: int) -> FallState:
        track = self.tracks.get(track_id)
        return track.state if track else FallState.UPRIGHT

    def _transition(self, track: TrackState, state: FallState, now: float) -> None:
        track.state = state
        track.state_since = now

    def _reset(self, track: TrackState, now: float) -> None:
        track.state = FallState.UPRIGHT
        track.state_since = now
        track.lying_since = None
        track.last_lying_at = None
        track.recovery_since = None
        track.peak_velocity = 0.0
        track.peak_angle = 0.0
        track.incident_id = None

    def _fall_score(
        self,
        track: TrackState,
        observation: PoseObservation,
        lying_duration: float,
    ) -> float:
        velocity_score = min(1.0, track.peak_velocity / max(self.config.descending_velocity_bh_s * 2, 1e-6))
        angle_span = max(90.0 - self.config.lying_torso_angle_deg, 1.0)
        angle_score = min(1.0, max(0.0, track.peak_angle - self.config.lying_torso_angle_deg) / angle_span)
        persistence_score = min(1.0, lying_duration / max(self.config.lying_confirmation_sec * 2, 1e-6))
        pose_score = min(1.0, observation.pose_confidence)
        score = 0.35 * velocity_score + 0.35 * angle_score + 0.20 * persistence_score + 0.10 * pose_score
        return round(max(0.0, min(1.0, score)), 4)

    @staticmethod
    def _new_event_id(timestamp: float) -> str:
        return f"EVT-{int(timestamp * 1000)}-{uuid.uuid4().hex[:8].upper()}"
