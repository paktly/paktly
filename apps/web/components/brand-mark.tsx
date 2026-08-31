import { PaktlyMark } from "./paktly-mark";

export function BrandMark() {
  return (
    <span aria-label="Paktly" className="brand-mark">
      <span aria-hidden="true" className="brand-symbol">
        <PaktlyMark />
      </span>
      <span>Paktly</span>
    </span>
  );
}
