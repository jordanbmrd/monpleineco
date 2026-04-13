import fs from "node:fs";
import path from "node:path";

export default function PrivacyPolicyPage() {
  const mdPath = path.join(process.cwd(), "src", "content", "privacy-policy.md");
  const content = fs.readFileSync(mdPath, "utf8");

  return (
    <main style={{ maxHeight: "100vh", overflowY: "auto", padding: "1rem" }}>
      <pre style={{ whiteSpace: "pre-wrap", margin: 0 }}>{content}</pre>
    </main>
  );
}
