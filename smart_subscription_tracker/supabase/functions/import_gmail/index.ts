import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import OpenAI from "https://deno.land/x/openai@v4.24.0/mod.ts";

const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY")! });

serve(async (req) => {
  try {
    const { emailSnippets, user_id } = await req.json();

    if (!Array.isArray(emailSnippets)) {
      return new Response(JSON.stringify({ error: "Missing email snippets" }), {
        status: 400,
      });
    }

    const prompt = `
You are a smart assistant that extracts subscription details from email text.
For each email snippet, return a JSON object with:
- name: name of the service
- price: number (USD)
- billing_cycle: 'monthly' | 'yearly' | 'weekly' | 'one-time'
- description: a short summary

Here are the email snippets:
${emailSnippets.map((text, i) => `Email ${i + 1}: ${text}`).join("\n\n")}

Return a JSON array of subscription objects.
`;

    const chatResponse = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.3,
    });

    const parsed = JSON.parse(chatResponse.choices[0].message.content || "[]");

    return new Response(JSON.stringify({ suggestions: parsed }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("AI Suggestion Error:", e);
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : "Unknown error" }),
      { status: 500 }
    );
  }
});
