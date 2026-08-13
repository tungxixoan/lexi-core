export interface GenerateContentParams {
  apiKey: string;
  model: string;
  prompt: string;
}

export interface GenerateContentResult {
  text: string;
}
