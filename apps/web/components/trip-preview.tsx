const members = ["AO", "MK", "JS", "LR"];

export function TripPreview() {
  return (
    <div className="preview-wrap" aria-label="Tokyo shared plan preview">
      <div className="orbit orbit-one" aria-hidden="true" />
      <div className="orbit orbit-two" aria-hidden="true" />
      <article className="phone-frame">
        <div className="phone-status" aria-hidden="true">
          <span>9:41</span>
          <span>● ● ▰</span>
        </div>
        <header className="trip-hero">
          <div className="trip-topline">
            <span className="eyebrow">SHARED PLAN</span>
            <span className="more-button">•••</span>
          </div>
          <h2>Tokyo, together.</h2>
          <p>Apr 3–12 · 4 people</p>
          <div className="avatar-stack" aria-label="Four people">
            {members.map((member, index) => (
              <span key={member} style={{ zIndex: members.length - index }}>
                {member}
              </span>
            ))}
          </div>
        </header>

        <section className="fund-card">
          <div>
            <span className="muted-label">SHARED GOAL</span>
            <strong>$4,350</strong>
            <span className="fund-target">of $6,000</span>
          </div>
          <span className="fund-percent">72%</span>
          <div className="progress-track" role="progressbar" aria-label="Shared goal funding progress" aria-valuemin={0} aria-valuemax={100} aria-valuenow={72}>
            <span />
          </div>
          <div className="fund-footer">
            <span>Next: $50 on Friday</span>
            <button type="button">Add money</button>
          </div>
        </section>

        <section className="snapshot">
          <div className="section-heading">
            <h3>Group snapshot</h3>
            <span>View all</span>
          </div>
          <div className="snapshot-grid">
            <div>
              <span className="snapshot-icon lavender">↗</span>
              <small>Spent</small>
              <strong>$1,284</strong>
            </div>
            <div>
              <span className="snapshot-icon coral">↔</span>
              <small>Your balance</small>
              <strong className="positive">+$75</strong>
            </div>
          </div>
        </section>

        <section className="activity-preview">
          <div className="section-heading">
            <h3>Latest</h3>
          </div>
          <div className="activity-item">
            <span className="activity-icon">🍜</span>
            <span><strong>Ramen in Shibuya</strong><small>Split with everyone</small></span>
            <strong>$86.40</strong>
          </div>
        </section>
      </article>
      <aside className="floating-card balance-float">
        <span className="float-icon">✓</span>
        <span><small>All caught up</small><strong>Balances reconciled</strong></span>
      </aside>
      <aside className="floating-card save-float">
        <span className="tiny-avatar">MK</span>
        <span><small>Maya contributed</small><strong>$50.00</strong></span>
      </aside>
    </div>
  );
}
