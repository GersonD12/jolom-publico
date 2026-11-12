import Link from "next/link";

type LegalSection = {
  title: string;
  body: readonly string[];
};

type LegalPageProps = {
  title: string;
  updatedAt: string;
  intro: string;
  sections: readonly LegalSection[];
};

export function LegalPage({
  title,
  updatedAt,
  intro,
  sections,
}: LegalPageProps) {
  return (
    <article className="bg-background">
      <div className="mx-auto w-full max-w-4xl px-6 py-16 sm:py-20">
        <Link
          href="/"
          className="text-sm font-medium text-primary transition-opacity hover:opacity-80"
        >
          Volver a Jolom
        </Link>

        <header className="mt-8 border-b border-outline/20 pb-8">
          <p className="text-sm font-medium text-muted">
            Última actualización: {updatedAt}
          </p>
          <h1 className="mt-3 text-4xl font-bold tracking-tight text-foreground sm:text-5xl">
            {title}
          </h1>
          <p className="mt-5 max-w-3xl text-base leading-8 text-muted">
            {intro}
          </p>
        </header>

        <div className="mt-10 space-y-10">
          {sections.map((section) => (
            <section key={section.title}>
              <h2 className="text-xl font-semibold tracking-tight text-foreground">
                {section.title}
              </h2>
              <div className="mt-4 space-y-4">
                {section.body.map((paragraph) => (
                  <p
                    key={paragraph}
                    className="text-base leading-8 text-muted text-pretty"
                  >
                    {paragraph}
                  </p>
                ))}
              </div>
            </section>
          ))}
        </div>
      </div>
    </article>
  );
}
