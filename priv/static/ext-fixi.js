document.addEventListener("fx:config", (evt) => {
    const template = document.getElementById(evt.detail.cfg.action)
    if (template) {
        evt.detail.cfg.fetch = () => ({ text: () => template.innerHTML }) // note the parens to make {} an object
    }
    if (evt.detail.cfg.action === "delete") {
        evt.detail.cfg.target = evt.detail.cfg.target.parentElement
        evt.detail.cfg.fetch = () => ({ text: () => "" })
    }
})