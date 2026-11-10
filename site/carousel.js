// The screenshots of the home page: a single line that scrolls and snaps. The arrow buttons are hidden until this script runs,
// so without JavaScript the line still scrolls by touch, wheel or keyboard.
(function () {
	var box = document.querySelector(".carousel");
	if (!box) { return; }
	var track = box.querySelector(".car-track");
	box.classList.add("js");
	var rtl = getComputedStyle(track).direction === "rtl";
	[["car-prev", -1], ["car-next", 1]].forEach(function (b) {
		var btn = box.querySelector("." + b[0]);
		btn.hidden = false;
		btn.addEventListener("click", function () {
			track.scrollBy({ left: b[1] * (rtl ? -1 : 1) * track.clientWidth * 0.8, behavior: "smooth" });
		});
	});
})();
