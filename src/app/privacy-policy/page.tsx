import fs from "node:fs";
import path from "node:path";

export default function PrivacyPolicyPage() {
  const mdPath = path.join(process.cwd(), "src", "content", "privacy-policy.md");
  const content = fs.readFileSync(mdPath, "utf8");

  return (
    <main>
      <pre style={{ whiteSpace: "pre-wrap" }}>{content}</pre>
    </main>
  );
}
