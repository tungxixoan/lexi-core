"use client";

import { useState, type FormEvent } from "react";
import { generateContent, type AiProvider } from "@/lib/generateContent";

export function GenerateContentPanel() {
  const [provider, setProvider] = useState<AiProvider>("gemini");
  const [apiKey, setApiKey] = useState("");
  const [model, setModel] = useState("gemini-2.5-flash");
  const [prompt, setPrompt] = useState("Say hello in Vietnamese.");
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const response = await generateContent({ provider, apiKey, model, prompt });
      setResult(response.text);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={(e) => void handleSubmit(e)}>
      <label>
        Provider
        <select
          value={provider}
          onChange={(e) => setProvider(e.target.value as AiProvider)}
        >
          <option value="gemini">Gemini</option>
          <option value="groq">Groq</option>
          <option value="openrouter">OpenRouter</option>
        </select>
      </label>
      <label>
        API key
        <input
          type="password"
          value={apiKey}
          onChange={(e) => setApiKey(e.target.value)}
        />
      </label>
      <label>
        Model
        <input value={model} onChange={(e) => setModel(e.target.value)} />
      </label>
      <label>
        Prompt
        <textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} />
      </label>
      <button type="submit" disabled={loading}>
        {loading ? "Đang gọi AI…" : "Tạo nội dung"}
      </button>
      {error && <p role="alert">{error}</p>}
      {result && <p data-testid="generate-content-result">{result}</p>}
    </form>
  );
}
