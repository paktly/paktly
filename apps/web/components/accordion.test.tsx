// @vitest-environment jsdom

import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { Accordion } from "./accordion";

afterEach(cleanup);

describe("Accordion", () => {
  it("keeps only one item open at a time", () => {
    render(
      <Accordion
        items={[
          ["First question", "First answer"],
          ["Second question", "Second answer"]
        ]}
      />
    );

    const first = screen.getByRole("button", { name: /first question/i });
    const second = screen.getByRole("button", { name: /second question/i });

    fireEvent.click(first);
    expect(first).toHaveAttribute("aria-expanded", "true");
    expect(second).toHaveAttribute("aria-expanded", "false");
    expect(screen.getByText("First answer")).toBeVisible();

    fireEvent.click(second);
    expect(first).toHaveAttribute("aria-expanded", "false");
    expect(second).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByText("First answer")).not.toBeVisible();
    expect(screen.getByText("Second answer")).toBeVisible();
  });

  it("allows the open item to be closed", () => {
    render(<Accordion items={[["Question", "Answer"]]} />);
    const trigger = screen.getByRole("button", { name: /question/i });

    fireEvent.click(trigger);
    fireEvent.click(trigger);

    expect(trigger).toHaveAttribute("aria-expanded", "false");
    expect(screen.getByText("Answer")).not.toBeVisible();
  });
});
