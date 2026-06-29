import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

const InputSchema = z.object({
  frames: z.array(z.string().startsWith("data:image/")).min(2).max(16),
});

export type FallDetectionResult = {
  fallDetected: boolean;
  confidence: number; // 0..1
  severity: "none" | "low" | "medium" | "high";
  timestampHint: string; // e.g. "khoảng giây thứ 3"
  description: string; // vi
  recommendation: string; // vi
};

export const analyzeFallVideo = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => InputSchema.parse(input))
  .handler(async ({ data }): Promise<FallDetectionResult> => {
    const key = process.env.LOVABLE_API_KEY;
    if (!key) throw new Error("Missing LOVABLE_API_KEY");

    const systemPrompt = `Bạn là mô hình thị giác AI của SilentGuard — chuyên phát hiện té ngã của người (đặc biệt người cao tuổi) qua chuỗi khung hình video. 
Phân tích chuỗi ảnh theo thứ tự thời gian. Phân biệt cú ngã thật (mất thăng bằng, cơ thể đập xuống sàn, nằm bất động) với hành động bình thường (ngồi xuống, cúi nhặt đồ, nằm nghỉ).
Trả về JSON duy nhất, không kèm văn bản khác, theo schema:
{
  "fallDetected": boolean,
  "confidence": number giữa 0 và 1,
  "severity": "none" | "low" | "medium" | "high",
  "timestampHint": string ngắn bằng tiếng Việt,
  "description": string mô tả ngắn bằng tiếng Việt (1-2 câu),
  "recommendation": string khuyến nghị bằng tiếng Việt (1 câu)
}`;

    const userContent: Array<Record<string, unknown>> = [
      {
        type: "text",
        text: `Đây là ${data.frames.length} khung hình trích từ video, theo thứ tự thời gian. Hãy phân tích và trả JSON theo schema yêu cầu.`,
      },
      ...data.frames.map((url) => ({
        type: "image_url",
        image_url: { url },
      })),
    ];

    const res = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Lovable-API-Key": key,
      },
      body: JSON.stringify({
        model: "google/gemini-2.5-flash",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        response_format: { type: "json_object" },
      }),
    });

    if (res.status === 429) throw new Error("Quá nhiều yêu cầu — vui lòng thử lại sau ít phút.");
    if (res.status === 402) throw new Error("Đã hết credit AI — vui lòng liên hệ quản trị viên.");
    if (!res.ok) {
      const t = await res.text().catch(() => "");
      throw new Error(`AI gateway lỗi ${res.status}: ${t.slice(0, 200)}`);
    }

    const json = await res.json();
    const content: string = json?.choices?.[0]?.message?.content ?? "";
    let parsed: unknown;
    try {
      parsed = JSON.parse(content);
    } catch {
      // strip code fences
      const match = content.match(/\{[\s\S]*\}/);
      if (!match) throw new Error("Không phân tích được phản hồi AI.");
      parsed = JSON.parse(match[0]);
    }

    const ResultSchema = z.object({
      fallDetected: z.boolean(),
      confidence: z.number().min(0).max(1),
      severity: z.enum(["none", "low", "medium", "high"]),
      timestampHint: z.string().max(200),
      description: z.string().max(600),
      recommendation: z.string().max(600),
    });
    return ResultSchema.parse(parsed);
  });
