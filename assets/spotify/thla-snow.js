(function thlaSnow() {
  if (document.getElementById("thla-snow")) return;

  const canvas = document.createElement("canvas");
  canvas.id = "thla-snow";
  document.body.appendChild(canvas);
  const ctx = canvas.getContext("2d");

  let w = 0, h = 0;
  const resize = () => {
    w = canvas.width = window.innerWidth;
    h = canvas.height = window.innerHeight;
  };
  resize();
  window.addEventListener("resize", resize);

  const COLORS = ["#ffffff", "#fff4e0"];
  const flakes = Array.from({ length: 60 }, () => ({
    x: Math.random() * window.innerWidth,
    y: Math.random() * window.innerHeight,
    r: 1 + Math.random() * 3,
    v: 0.4 + Math.random() * 1.1,
    sway: 8 + Math.random() * 22,
    phase: Math.random() * Math.PI * 2,
    star: Math.random() < 0.18,
    c: COLORS[Math.floor(Math.random() * COLORS.length)],
  }));

  let t = 0;
  function frame() {
    if (document.hidden) return requestAnimationFrame(frame);
    t += 0.01;
    ctx.clearRect(0, 0, w, h);
    for (const f of flakes) {
      f.y += f.v;
      if (f.y > h + 8) { f.y = -8; f.x = Math.random() * w; }
      const x = f.x + Math.sin(t * 2 + f.phase) * f.sway;
      ctx.globalAlpha = 0.35 + f.r / 9;
      if (f.star) {
        ctx.font = `${f.r * 5 + 6}px sans-serif`;
        ctx.fillStyle = f.c;
        ctx.fillText("❄", x, f.y);
      } else {
        ctx.beginPath();
        ctx.arc(x, f.y, f.r, 0, Math.PI * 2);
        ctx.fillStyle = f.c;
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
    requestAnimationFrame(frame);
  }
  frame();

  const BITS = ["❄️", "✨", "❤️", "🎄", "⭐", "🎁"];
  document.addEventListener("click", (e) => {
    for (let i = 0; i < 5; i++) {
      const s = document.createElement("span");
      s.className = "thla-pop";
      s.textContent = BITS[Math.floor(Math.random() * BITS.length)];
      s.style.left = e.clientX + "px";
      s.style.top = e.clientY + "px";
      s.style.setProperty("--dx", (Math.random() * 90 - 45) + "px");
      s.style.setProperty("--dy", (-30 - Math.random() * 60) + "px");
      s.style.setProperty("--rot", (Math.random() * 120 - 60) + "deg");
      document.body.appendChild(s);
      setTimeout(() => s.remove(), 950);
    }
  }, true);
})();
