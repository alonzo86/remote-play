// The links of the apps in Google Play. `play` is the phone app (Sababi: Remote), used by the home page and by /get/ (the page that
// the QR code "GET THE PHONE APP TO PLAY" of the TV opens); `playTv` is the TV app (Sababi: TV Games, Android TV).
// The addresses are made from the package ids of the apps (`export_presets.cfg`): they work when the apps are published.
// There is no App Store badge or link: removed by the owner on 2026-11-09 (Apple allows its badge only for an app that is available).
// An empty address shows the badge without a link.
window.SABABI_STORES = {
  play: "https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.controller",      // Google Play, phone app (Sababi: Remote)
  playTv: "https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.tv"     // Google Play, TV app (Sababi: TV Games)
};
(function () {
  var s = window.SABABI_STORES;
  document.querySelectorAll("[data-store]").forEach(function (a) {
    var url = s[a.getAttribute("data-store")];
    if (url) { a.href = url; a.removeAttribute("aria-disabled"); }
    else { a.removeAttribute("href"); a.setAttribute("aria-disabled", "true"); }
  });
})();
