A panel with the double frame: a 6px `text` line, 6px of black, a 6px `frame` blue line, then the content.

Used for the QR code, modals and the menu cards of the games. The corners are square, there is no shadow. Padding inside the frame is 24px (`space-24`) or more. The frame is drawn by `scripts/ui/arcade_frame.gd` (`UiTheme.frame()`). A box with a single 6px line (`UiTheme.line_box()`) is for tiles, the players badge, OPTIONS and the phone buttons.
