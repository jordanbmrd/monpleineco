import fs from "fs";
import path from "path";
import { remark } from "remark";
import remarkHtml from "remark-html";

export const metadata = {
  title: "Politique de confidentialité — Mon Plein Éco",
};

export default async function PrivacyPolicyPage() {
  const filePath = path.join(process.cwd(), "src/content/privacy-policy.md");
  const fileContent = fs.readFileSync(filePath, "utf8");

  // Content is from a static, version-controlled file — not user input.
  const processed = await remark()
    .use(remarkHtml, { sanitize: true })
    .process(fileContent);
  const contentHtml = processed.toString();

  return (
    <main style={{ maxWidth: 800, margin: "0 auto", padding: "2rem 1rem" }}>
      {/* sanitize:true is applied above; source is a static repo file */}
      <div dangerouslySetInnerHTML={{ __html: contentHtml }} />
    </main>
  );
}
