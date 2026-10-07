(() => {
  const root = document.documentElement;
  const themeButton = document.querySelector("#theme-button");
  const menuButton = document.querySelector("#menu-button");
  const backdrop = document.querySelector("#backdrop");
  const search = document.querySelector("#nav-search");
  const links = [...document.querySelectorAll("#docs-nav a")];
  const sections = [...document.querySelectorAll("main .doc-section")];
  const stored = localStorage.getItem("hutame-docs-theme");
  if (stored === "light" || stored === "dark") root.dataset.theme = stored;
  themeButton.addEventListener("click", () => {
    const next = root.dataset.theme === "light" ? "dark" : "light";
    root.dataset.theme = next;
    localStorage.setItem("hutame-docs-theme", next);
  });
  function closeMenu() { document.body.classList.remove("menu-open"); menuButton.setAttribute("aria-expanded", "false"); }
  menuButton.addEventListener("click", () => {
    const open = document.body.classList.toggle("menu-open");
    menuButton.setAttribute("aria-expanded", String(open));
  });
  backdrop.addEventListener("click", closeMenu);
  links.forEach(link => link.addEventListener("click", closeMenu));
  document.addEventListener("keydown", event => {
    if (event.key === "Escape") closeMenu();
    if (event.key === "/" && !["INPUT", "TEXTAREA"].includes(document.activeElement.tagName)) {
      event.preventDefault(); search.focus();
    }
  });
  search.addEventListener("input", () => {
    const query = search.value.toLocaleLowerCase("tr").trim();
    let visible = 0;
    links.forEach(link => {
      const match = link.textContent.toLocaleLowerCase("tr").includes(query);
      link.hidden = !match; if (match) visible++;
    });
    document.querySelectorAll(".nav-heading").forEach(heading => {
      let next = heading.nextElementSibling, found = false;
      while (next && !next.classList.contains("nav-heading")) {
        if (!next.hidden) found = true;
        next = next.nextElementSibling;
      }
      heading.hidden = !found;
    });
    search.setAttribute("aria-label", visible ? "Başlık ara" : "Eşleşen başlık yok");
  });
  document.querySelectorAll(".copy-button").forEach(button => button.addEventListener("click", async () => {
    const code = button.parentElement.nextElementSibling?.textContent || "";
    try {
      await navigator.clipboard.writeText(code);
      button.textContent = "Kopyalandı ✓";
      setTimeout(() => { button.textContent = "Kopyala"; }, 1800);
    } catch {
      button.textContent = "Kopyalanamadı";
      setTimeout(() => { button.textContent = "Kopyala"; }, 1800);
    }
  }));
  const observer = new IntersectionObserver(entries => {
    const current = entries.filter(entry => entry.isIntersecting).sort((a,b) => b.intersectionRatio - a.intersectionRatio)[0];
    if (!current) return;
    links.forEach(link => {
      const active = link.hash === "#" + current.target.id;
      link.classList.toggle("active", active);
      if (active) link.setAttribute("aria-current", "location"); else link.removeAttribute("aria-current");
    });
  }, { rootMargin: "-80px 0px -55% 0px", threshold: [0, .25, .5, 1] });
  sections.forEach(section => observer.observe(section));
})();
