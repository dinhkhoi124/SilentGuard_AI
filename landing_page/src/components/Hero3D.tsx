import { Suspense, useMemo, useRef } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import {
  Float,
  Environment,
  ContactShadows,
  MeshTransmissionMaterial,
  Sparkles,
} from "@react-three/drei";
import * as THREE from "three";

function ScanCone() {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((state) => {
    if (!ref.current) return;
    const t = state.clock.elapsedTime;
    ref.current.rotation.z = Math.sin(t * 0.6) * 0.25;
    const mat = ref.current.material as THREE.MeshBasicMaterial;
    mat.opacity = 0.12 + (Math.sin(t * 1.4) * 0.5 + 0.5) * 0.1;
  });
  return (
    <mesh ref={ref} position={[1.3, -0.1, 0]} rotation={[0, 0, -Math.PI / 2]}>
      <coneGeometry args={[1.4, 3.2, 32, 1, true]} />
      <meshBasicMaterial
        color="#22c55e"
        transparent
        opacity={0.18}
        side={THREE.DoubleSide}
        depthWrite={false}
      />
    </mesh>
  );
}

function Camera() {
  const group = useRef<THREE.Group>(null);
  const led = useRef<THREE.MeshStandardMaterial>(null);

  useFrame((state) => {
    if (!group.current) return;
    const t = state.clock.elapsedTime;
    // Subtle pan as if scanning
    group.current.rotation.y = Math.sin(t * 0.4) * 0.35;
    group.current.rotation.x = Math.cos(t * 0.3) * 0.08;
    if (led.current) {
      led.current.emissiveIntensity = 1.2 + Math.sin(t * 3) * 0.6;
    }
  });

  return (
    <group ref={group}>
      {/* Mount arm */}
      <mesh position={[0, -1.6, -0.4]} castShadow>
        <cylinderGeometry args={[0.08, 0.1, 1.4, 24]} />
        <meshStandardMaterial color="#3a3a3a" metalness={0.7} roughness={0.4} />
      </mesh>
      {/* Mount base */}
      <mesh position={[0, -2.3, -0.4]} castShadow>
        <cylinderGeometry args={[0.5, 0.55, 0.12, 32]} />
        <meshStandardMaterial color="#2a2a2a" metalness={0.6} roughness={0.5} />
      </mesh>

      {/* Camera body (rounded capsule shape) */}
      <mesh castShadow receiveShadow>
        <capsuleGeometry args={[0.85, 1.1, 16, 24]} />
        <meshStandardMaterial color="#f5f5f4" metalness={0.15} roughness={0.45} />
      </mesh>

      {/* Front bezel ring */}
      <mesh position={[0.95, 0, 0]} rotation={[0, 0, Math.PI / 2]} castShadow>
        <torusGeometry args={[0.62, 0.08, 16, 48]} />
        <meshStandardMaterial color="#1a1a1a" metalness={0.85} roughness={0.2} />
      </mesh>

      {/* Lens housing */}
      <mesh position={[1.02, 0, 0]} rotation={[0, 0, Math.PI / 2]} castShadow>
        <cylinderGeometry args={[0.55, 0.6, 0.25, 48]} />
        <meshStandardMaterial color="#0a0a0a" metalness={0.5} roughness={0.3} />
      </mesh>

      {/* Glass lens */}
      <mesh position={[1.16, 0, 0]} rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[0.48, 0.48, 0.06, 48]} />
        <MeshTransmissionMaterial
          thickness={0.3}
          transmission={1}
          roughness={0.05}
          ior={1.5}
          chromaticAberration={0.05}
          backside
          color="#bbf7d0"
        />
      </mesh>

      {/* Inner lens reflection */}
      <mesh position={[1.12, 0, 0]} rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[0.32, 0.32, 0.02, 48]} />
        <meshStandardMaterial
          color="#0c1f14"
          metalness={1}
          roughness={0.1}
          emissive="#166534"
          emissiveIntensity={0.4}
        />
      </mesh>

      {/* Status LED */}
      <mesh position={[0.35, 0.62, 0.55]}>
        <sphereGeometry args={[0.06, 16, 16]} />
        <meshStandardMaterial
          ref={led}
          color="#22c55e"
          emissive="#22c55e"
          emissiveIntensity={1.4}
        />
      </mesh>

      {/* Scanning cone (AI vision indicator) */}
      <ScanCone />
    </group>
  );
}

function FloatingAlert({
  position,
  color = "#166534",
}: {
  position: [number, number, number];
  color?: string;
}) {
  return (
    <Float speed={2} rotationIntensity={0.3} floatIntensity={1.2}>
      <mesh position={position}>
        <boxGeometry args={[1.2, 0.45, 0.08]} />
        <meshStandardMaterial color="#ffffff" roughness={0.35} />
      </mesh>
      <mesh position={[position[0] - 0.45, position[1], position[2] + 0.05]}>
        <sphereGeometry args={[0.08, 16, 16]} />
        <meshStandardMaterial color={color} emissive={color} emissiveIntensity={1.5} />
      </mesh>
    </Float>
  );
}

function Particles() {
  const points = useMemo(() => {
    const arr: [number, number, number][] = [];
    for (let i = 0; i < 40; i++) {
      arr.push([
        (Math.random() - 0.5) * 10,
        (Math.random() - 0.5) * 8,
        (Math.random() - 0.5) * 6 - 2,
      ]);
    }
    return arr;
  }, []);
  return (
    <>
      {points.map((p, i) => (
        <mesh key={i} position={p}>
          <sphereGeometry args={[0.02, 8, 8]} />
          <meshBasicMaterial color="#166534" transparent opacity={0.4} />
        </mesh>
      ))}
    </>
  );
}

export function Hero3D() {
  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: [0, 0.4, 6.5], fov: 35 }}
      gl={{ antialias: true, alpha: true }}
    >
      <color attach="background" args={["#00000000"]} />
      <ambientLight intensity={0.4} />
      <directionalLight
        position={[5, 5, 5]}
        intensity={1.2}
        castShadow
        shadow-mapSize={[1024, 1024]}
      />
      <directionalLight position={[-4, 2, -3]} intensity={0.5} color="#a7f3d0" />
      <spotLight position={[0, 6, 4]} angle={0.4} penumbra={1} intensity={1.5} color="#22c55e" />

      <Suspense fallback={null}>
        <Float speed={1.2} rotationIntensity={0.3} floatIntensity={0.5}>
          <Camera />
        </Float>

        <FloatingAlert position={[-2.6, 1.6, 0.5]} />
        <FloatingAlert position={[2.4, -1.6, 0.2]} color="#fb923c" />

        <Sparkles count={60} scale={8} size={2} speed={0.3} color="#166534" opacity={0.6} />
        <Particles />

        <ContactShadows
          position={[0, -2.6, 0]}
          opacity={0.35}
          scale={10}
          blur={2.5}
          far={4}
          color="#166534"
        />

        <Environment preset="city" />
      </Suspense>
    </Canvas>
  );
}
