// The language menu of the header (<details class="lang">): it closes on a click outside it, on Escape and when a language is chosen.
(function () {
  document.addEventListener("click", function (e) {
    document.querySelectorAll("details.lang[open]").forEach(function (d) {
      // Outside the menu, or on one of its links (a language is chosen): close it. A click on the button itself toggles it.
      if (!d.contains(e.target) || e.target.closest("ul a")) { d.open = false; }
    });
  });
  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape") { return; }
    document.querySelectorAll("details.lang[open]").forEach(function (d) { d.open = false; d.querySelector("summary").focus(); });
  });
})();
