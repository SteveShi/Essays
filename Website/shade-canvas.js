const shadeCanvas = document.getElementById("shade-canvas");

if (shadeCanvas) {
  const shadeContext = shadeCanvas.getContext("2d");
  const shadeModes = new Set(["day", "sunny", "moonlight", "rainy"]);
  const offscreenCache = {};
  let lastTime = 0;
  let fadeValue = 0;
  let fadeTarget = 0;

  const fitCanvas = () => {
    shadeCanvas.width = window.innerWidth;
    shadeCanvas.height = window.innerHeight;
  };

  const lerp = (from, to, t) => from + (to - from) * t;
  const lerpColor = (from, to, t) => [
    Math.round(lerp(from[0], to[0], t)),
    Math.round(lerp(from[1], to[1], t)),
    Math.round(lerp(from[2], to[2], t))
  ];

  const getAnimTime = (now) => {
    const period = 120000;
    const phase = (now % (period * 2)) / period;
    const tri = phase < 1 ? phase : 2 - phase;
    return tri * 0.1;
  };

  const getAnimOpen = (now) =>
    0.5 + Math.sin(now * 0.00006) * 0.04 + Math.sin(now * 0.00015) * 0.02;

  const getOffscreen = (key, width, height) => {
    const cached = offscreenCache[key];
    if (cached && cached.width === width && cached.height === height) {
      return cached;
    }
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    offscreenCache[key] = canvas;
    return canvas;
  };

  const getActiveMode = () => {
    const classes = document.documentElement.classList;
    for (const mode of shadeModes) {
      if (classes.contains(`mode-${mode}`)) {
        return mode;
      }
    }
    return null;
  };

  const updateFadeTarget = () => {
    fadeTarget = getActiveMode() ? 1 : 0;
  };

  const draw = (now) => {
    const delta = lastTime ? (now - lastTime) / 1000 : 0.016;
    lastTime = now;
    const speed = delta / 1.8;

    if (fadeValue < fadeTarget) {
      fadeValue = Math.min(fadeValue + speed, 1);
    } else if (fadeValue > fadeTarget) {
      fadeValue = Math.max(fadeValue - speed, 0);
    }

    const fadeEase = fadeValue * fadeValue * (3 - 2 * fadeValue);
    const width = shadeCanvas.width;
    const height = shadeCanvas.height;

    shadeContext.clearRect(0, 0, width, height);

    if (fadeValue === 0) {
      requestAnimationFrame(draw);
      return;
    }

    const time = getAnimTime(now);
    const open = getAnimOpen(now);
    const normalized = time / 0.35;

    const shadowTarget = lerpColor([228, 214, 196], [234, 224, 210], normalized);
    const shadowTint = lerpColor([255, 255, 255], shadowTarget, fadeEase);
    const warmLightTarget = lerpColor([255, 215, 155], [255, 230, 190], normalized);
    const warmLight = lerpColor([255, 255, 255], warmLightTarget, fadeEase);

    const skewX = lerp(0.34, 0.26, normalized);
    const skewY = lerp(0.13, 0.09, normalized);
    const stretch = lerp(1.9, 1.6, normalized);
    const warmAlpha = lerp(0.28, 0.17, normalized) * fadeEase;
    const baseSoft = lerp(12, 7, normalized);

    shadeContext.fillStyle = `rgb(${shadowTint[0]},${shadowTint[1]},${shadowTint[2]})`;
    shadeContext.fillRect(0, 0, width, height);

    const projectionWidth = Math.min(width * 0.58, 420) * stretch;
    const projectionHeight = Math.min(height * 0.72, 500) * stretch * 0.78;
    const driftX = Math.sin(now * 0.00009) * 5 + Math.sin(now * 0.00025) * 2.5;
    const driftY = Math.cos(now * 0.00011) * 3.5 + Math.cos(now * 0.00022) * 1.8;
    const offsetX = lerp(width * 0.01, width * 0.06, normalized) + driftX;
    const offsetY = lerp(height * 0.01, height * 0.03, normalized) + driftY;
    const frameThickness = lerp(10, 7, normalized);
    const slats = 18;
    const innerHeight = projectionHeight - frameThickness * 2;
    const spacing = innerHeight / slats;
    const slatThickness = spacing * lerp(0.88, 0.12, open);
    const gapHeight = spacing - slatThickness;

    if (gapHeight < 0.3) {
      requestAnimationFrame(draw);
      return;
    }

    shadeContext.save();
    shadeContext.translate(offsetX, offsetY);
    shadeContext.transform(1, skewY, skewX, 1, 0, 0);

    const offWidth = Math.ceil(projectionWidth + 80);
    const offHeight = Math.ceil(projectionHeight + 80);
    const offCanvas = getOffscreen("off", offWidth, offHeight);
    const offContext = offCanvas.getContext("2d");
    offContext.clearRect(0, 0, offWidth, offHeight);

    for (let i = 0; i < slats; i += 1) {
      const baseY = frameThickness + i * spacing + slatThickness;
      const wobble = Math.sin(now * 0.00008 + i * 0.53) * 1.1 + Math.sin(now * 0.00019 + i * 0.79) * 0.6;
      const y = baseY + wobble;
      const vertical = i / slats;
      const slatSoft = baseSoft * (0.55 + vertical * 1.0);
      const distCenter = Math.abs(i - slats / 2) / (slats / 2);
      const slatAlpha = 1.0 - distCenter * 0.1;
      const pad = slatSoft * 1.2;
      const gradient = offContext.createLinearGradient(0, y - pad, 0, y + gapHeight + pad);
      gradient.addColorStop(0, "rgba(255,255,255,0)");
      gradient.addColorStop(pad / (gapHeight + pad * 2), `rgba(255,255,255,${slatAlpha})`);
      gradient.addColorStop(1 - pad / (gapHeight + pad * 2), `rgba(255,255,255,${slatAlpha})`);
      gradient.addColorStop(1, "rgba(255,255,255,0)");
      offContext.fillStyle = gradient;
      offContext.fillRect(frameThickness, y - pad, projectionWidth - frameThickness * 2, gapHeight + pad * 2);
    }

    offContext.globalCompositeOperation = "destination-in";
    const horizontal = offContext.createLinearGradient(frameThickness, 0, projectionWidth - frameThickness, 0);
    horizontal.addColorStop(0, "rgba(255,255,255,0.1)");
    horizontal.addColorStop(0.06, "rgba(255,255,255,0.55)");
    horizontal.addColorStop(0.15, "rgba(255,255,255,1)");
    horizontal.addColorStop(0.5, "rgba(255,255,255,1)");
    horizontal.addColorStop(0.72, "rgba(255,255,255,0.8)");
    horizontal.addColorStop(0.85, "rgba(255,255,255,0.35)");
    horizontal.addColorStop(0.94, "rgba(255,255,255,0.12)");
    horizontal.addColorStop(1, "rgba(255,255,255,0.02)");
    offContext.fillStyle = horizontal;
    offContext.fillRect(0, 0, offWidth, offHeight);

    const vertical = offContext.createLinearGradient(0, frameThickness, 0, projectionHeight - frameThickness);
    vertical.addColorStop(0, "rgba(255,255,255,0.15)");
    vertical.addColorStop(0.5, "rgba(255,255,255,1)");
    vertical.addColorStop(1, "rgba(255,255,255,0.2)");
    offContext.fillStyle = vertical;
    offContext.fillRect(0, 0, offWidth, offHeight);

    shadeContext.drawImage(offCanvas, 0, 0);

    const glowCanvas = getOffscreen("glow", offWidth, offHeight);
    const glowContext = glowCanvas.getContext("2d");
    glowContext.clearRect(0, 0, offWidth, offHeight);
    const glowX = projectionWidth * 0.38;
    const glowY = projectionHeight * 0.42;
    const glow = glowContext.createRadialGradient(glowX, glowY, 0, glowX, glowY, projectionWidth * 0.7);
    glow.addColorStop(0, `rgba(${warmLight[0]},${warmLight[1]},${warmLight[2]},${warmAlpha * 0.35})`);
    glow.addColorStop(0.5, `rgba(${warmLight[0]},${warmLight[1]},${warmLight[2]},${warmAlpha * 0.15})`);
    glow.addColorStop(1, "rgba(255,235,200,0)");
    glowContext.fillStyle = glow;
    glowContext.fillRect(0, 0, offWidth, offHeight);
    glowContext.globalCompositeOperation = "destination-in";
    glowContext.drawImage(offCanvas, 0, 0);
    glowContext.globalCompositeOperation = "source-over";
    shadeContext.drawImage(glowCanvas, 0, 0);

    shadeContext.restore();
    requestAnimationFrame(draw);
  };

  const observer = new MutationObserver(updateFadeTarget);
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });

  window.addEventListener("resize", fitCanvas);
  fitCanvas();
  updateFadeTarget();
  requestAnimationFrame(draw);
}
