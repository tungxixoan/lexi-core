import { SignInButton } from "@/components/SignInButton";
import { VocabRecordCount } from "@/components/VocabRecordCount";
import { GenerateContentPanel } from "@/components/GenerateContentPanel";

export default function HomePage() {
  return (
    <main>
      <h1>LexiCore Web</h1>
      <SignInButton />
      <VocabRecordCount />
      <GenerateContentPanel />
    </main>
  );
}
