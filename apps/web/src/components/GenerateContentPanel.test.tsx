import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { GenerateContentPanel } from "./GenerateContentPanel";
import { generateContent } from "@/lib/generateContent";

vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));

describe("GenerateContentPanel", () => {
  it("calls generateContent with the form values and displays the result", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: "Xin chào!" });
    render(<GenerateContentPanel />);

    fireEvent.change(screen.getByLabelText("API key"), {
      target: { value: "test-key" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Tạo nội dung" }));

    await waitFor(() =>
      expect(screen.getByTestId("generate-content-result")).toHaveTextContent(
        "Xin chào!"
      )
    );
    expect(generateContent).toHaveBeenCalledWith({
      provider: "gemini",
      apiKey: "test-key",
      model: "gemini-2.5-flash",
      prompt: "Say hello in Vietnamese.",
    });
  });

  it("shows an error message when generateContent rejects", async () => {
    vi.mocked(generateContent).mockRejectedValue(new Error("unauthenticated"));
    render(<GenerateContentPanel />);
    fireEvent.click(screen.getByRole("button", { name: "Tạo nội dung" }));
    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("unauthenticated")
    );
  });
});
