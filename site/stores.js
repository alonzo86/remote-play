// The links of the apps in the stores. Empty means "coming soon": fill in each address when the app has its page.
// `play` and `appStore` are the phone app (Sababi: Remote), used by the home page and by /get/ (the page that the QR code
// "GET THE PHONE APP TO PLAY" of the TV opens); `playTv` is the TV app (Sababi: TV Games, Google Play, Android TV).
window.SABABI_STORES = {
  play: "",      // Google Play, phone app: https://play.google.com/store/apps/details?id=...
  appStore: "",  // App Store, phone app: https://apps.apple.com/app/id...
  playTv: ""     // Google Play, TV app: https://play.google.com/store/apps/details?id=...
};
(function () {
  var s = window.SABABI_STORES;
  var soon = document.documentElement.lang === "he" ? "בקרוב" : "Coming soon";
  document.querySelectorAll("[data-store]").forEach(function (a) {
    var url = s[a.getAttribute("data-store")];
    if (url) { a.href = url; a.removeAttribute("aria-disabled"); a.querySelector("small").textContent = a.getAttribute("data-open"); }
    else { a.removeAttribute("href"); a.setAttribute("aria-disabled", "true"); a.querySelector("small").textContent = soon; }
  });
})();
