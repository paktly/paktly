"use client";

import { useId, useState } from "react";

type AccordionItem = readonly [question: string, answer: string];

type AccordionProps = {
  items: readonly AccordionItem[];
};

export function Accordion({ items }: AccordionProps) {
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const instanceId = useId().replaceAll(":", "");

  return (
    <div className="accordion">
      {items.map(([question, answer], index) => {
        const isOpen = openIndex === index;
        const triggerId = `${instanceId}-trigger-${index}`;
        const panelId = `${instanceId}-panel-${index}`;

        return (
          <section className="accordion-item" key={question}>
            <h2>
              <button
                id={triggerId}
                type="button"
                aria-expanded={isOpen}
                aria-controls={panelId}
                onClick={() => setOpenIndex(isOpen ? null : index)}
              >
                <span>{question}</span>
                <span className="accordion-icon" aria-hidden="true">
                  {isOpen ? "−" : "+"}
                </span>
              </button>
            </h2>
            <div
              id={panelId}
              role="region"
              aria-labelledby={triggerId}
              hidden={!isOpen}
              className="accordion-panel"
            >
              <p>{answer}</p>
            </div>
          </section>
        );
      })}
    </div>
  );
}
