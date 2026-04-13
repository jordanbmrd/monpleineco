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

  const processed = await remark().use(remarkHtml).process(fileContent);
  const contentHtml = processed.toString();

  return (
    <main style={{ maxWidth: 800, margin: "0 auto", padding: "2rem 1rem" }}>
      <div dangerouslySetInnerHTML={{ __html: contentHtml }} />
    </main>
  );
}
