import fs from "node:fs";
import path from "node:path";

export default function PrivacyPolicyPage() {
  const mdPath = path.join(process.cwd(), "src", "content", "privacy-policy.md");
  const content = fs.readFileSync(mdPath, "utf8");

  return (
    <main
      style={{
        height: "100vh",
        overflowY: "auto",
        WebkitOverflowScrolling: "touch",
        padding: 16,
      }}
    >
      <pre style={{ margin: 0, whiteSpace: "pre-wrap" }}>{content}</pre>
    </main>
  );
}
