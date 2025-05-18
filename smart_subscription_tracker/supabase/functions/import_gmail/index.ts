import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import OpenAI from "https://deno.land/x/openai@v4.26.0/mod.ts";

// Initialize OpenAI client (replace with your actual API key or use env variable)
const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY") ?? "",
});

// Fetches Gmail messages using the user's OAuth token
async function fetchGmailSubscriptions(oauth_token: string): Promise<any[]> {
  // Fetch fewer messages for speed
  const listRes = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=5&q=subscription OR receipt OR invoice",
    {
      headers: {
        Authorization: `Bearer ${oauth_token}`,
        Accept: "application/json",
      },
    }
  );

  if (!listRes.ok) {
    throw new Error(`Failed to fetch Gmail messages: ${await listRes.text()}`);
  }

  const listData = await listRes.json();
  const messages = listData.messages || [];

  // Fetch message details in parallel
  const messageDetails = await Promise.all(
    messages.map((msg: { id: string }) =>
      fetch(
        `https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}?format=metadata&metadataHeaders=subject`,
        {
          headers: {
            Authorization: `Bearer ${oauth_token}`,
            Accept: "application/json",
          },
        }
      ).then((res) => (res.ok ? res.json() : null))
    )
  );

  const subscriptions: any[] = [];
  for (const msgData of messageDetails) {
    if (!msgData) continue;
    const subjectHeader = (msgData.payload?.headers || []).find(
      (h: any) => h.name.toLowerCase() === "subject"
    );
    const subject = subjectHeader?.value || "";
    if (/subscription|receipt|invoice/i.test(subject)) {
      subscriptions.push({
        id: msgData.id,
        name: subject,
        price: 0,
        billingCycle: "Unknown",
        nextPaymentDate: null,
        isShared: false,
      });
    }
  }
  return subscriptions;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
    });
  }

  const { oauth_token } = body;

  if (!oauth_token) {
    return new Response(
      JSON.stringify({ error: "Missing required field: oauth_token" }),
      { status: 400 }
    );
  }

  try {
    const subscriptions = await fetchGmailSubscriptions(oauth_token);
    return new Response(JSON.stringify(subscriptions), { status: 200 });
  } catch (e) {
    const errorMessage = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
    });
  }
});
