// Fixed Lights Out appearance for the app's X pages, including their first paint.
(() => {
  const host = location.hostname.toLowerCase()
  const domain = ['x.com', 'twitter.com'].find(d => host === d || host.endsWith('.' + d))
  if (!domain) return
  const style = document.createElement('style')
  style.id = 'custom-twitter-black-theme'
  style.textContent = `
    :root { color-scheme: dark !important; background-color: #000 !important; }
    html, body, #react-root, main, header[role="banner"],
    [data-testid="primaryColumn"], [data-testid="sidebarColumn"],
    [data-testid="TopNavBar"], [data-testid="BottomBar"],
    [role="dialog"], [role="menu"], [role="listbox"], [role="option"], [role="tooltip"],
    [data-testid="sheetDialog"], [data-testid="DMDrawer"],
    [data-testid="SearchBox_Search_Input_label"],
    .bg-gray-0, .bg-gray-50, .bg-gray-100,
    input:not([type="checkbox"]):not([type="radio"]):not([type="range"]):not([type="button"]):not([type="submit"]):not([type="color"]),
    textarea { background-color: #000 !important; }
    textarea, input:not([type="checkbox"]):not([type="radio"]):not([type="range"]):not([type="button"]):not([type="submit"]):not([type="color"]) { color: #e7e9ea !important; }
    body { color: #e7e9ea !important; }
  `
  let body
  const bodyObserver = new MutationObserver(() => enforce())
  const enforce = () => {
    if (document.documentElement && !style.isConnected) (document.head || document.documentElement).append(style)
    if (document.body && body !== document.body) {
      bodyObserver.disconnect()
      body = document.body
      bodyObserver.observe(body, { attributes: true, attributeFilter: ['style'] })
    }
    if (body && (body.style.backgroundColor !== 'rgb(0, 0, 0)' || body.style.getPropertyPriority('background-color') !== 'important')) {
      body.style.setProperty('background-color', '#000', 'important')
    }
    if (!document.cookie.split(';').some(c => c.trim() === 'night_mode=2')) {
      document.cookie = `night_mode=2; Domain=.${domain}; Path=/; Max-Age=31536000; SameSite=Lax; Secure`
    }
  }
  // Watch only document/head replacement and the body theme attribute. Tweet
  // insertions do not trigger a full-tree scan or a permanent polling timer.
  const rootObserver = new MutationObserver(() => {
    enforce()
    if (document.head && document.body) {
      rootObserver.disconnect()
      rootObserver.observe(document.documentElement, { childList: true })
      rootObserver.observe(document.head, { childList: true })
    }
  })
  rootObserver.observe(document, { childList: true, subtree: true })
  enforce()
})()
