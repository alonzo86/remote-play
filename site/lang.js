// The language menu of the header (<details class="lang">): it closes on a click outside it, on Escape and when a language is chosen.
(function () {
  document.addEventListener("click", function (e) {
    document.querySelectorAll("details.lang[open]").forEach(function (d) { if (!d.contains(e.target)) { d.open = false; } });
  });
  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape") { return; }
    document.querySelectorAll("details.lang[open]").forEach(function (d) { d.open = false; d.querySelector("summary").focus(); });
  });
})();
