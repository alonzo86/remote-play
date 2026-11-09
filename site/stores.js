// The links of the apps in the stores. Empty means "coming soon": fill in each address when the app has its page.
// `play` and `appStore` are the phone app (Sababi: Remote), used by the home page and by /get/ (the page that the QR code
// "GET THE PHONE APP TO PLAY" of the TV opens); `playTv` is the TV app (Sababi: TV Games, Google Play, Android TV).
// The Google Play addresses are made from the package ids of the apps (`export_presets.cfg`): they work when the apps are
// published. The App Store has no address yet: its badge shows "Coming soon" (owner, 2026-11-09).
window.SABABI_STORES = {
  play: "https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.controller",      // Google Play, phone app (Sababi: Remote)
  appStore: "",  // App Store, phone app: https://apps.apple.com/app/id...
  playTv: "https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.tv"     // Google Play, TV app (Sababi: TV Games)
};
(function () {
  var s = window.SABABI_STORES;
  var soon = document.documentElement.lang === "he" ? "בקרוב" : "Coming soon";
  document.querySelectorAll("[data-store]").forEach(function (a) {
    var url = s[a.getAttribute("data-store")];
    var caption = a.parentNode.querySelector(".soon");
    if (url) { a.href = url; a.removeAttribute("aria-disabled"); if (caption) { caption.textContent = ""; } }
    else { a.removeAttribute("href"); a.setAttribute("aria-disabled", "true"); if (caption) { caption.textContent = soon; } }
  });
})();
