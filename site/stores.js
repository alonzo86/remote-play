// The links of the phone app in the stores. Empty means "coming soon": fill in each address when the app has its page.
// Used by the home page and by /get/ (the page that the QR code "GET THE PHONE APP TO PLAY" of the TV opens).
window.SABABI_STORES = {
  play: "",      // Google Play: https://play.google.com/store/apps/details?id=...
  appStore: ""   // App Store: https://apps.apple.com/app/id...
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
