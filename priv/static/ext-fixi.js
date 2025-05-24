let JimGymApp = {}

document.addEventListener("fx:config", (evt) => {
    const template = document.getElementById(evt.detail.cfg.action)
    if (template) {
        JimGymApp.template = JimGymApp.template ?? 0
        JimGymApp.template++
        evt.detail.cfg.fetch = () => ({ text: () => template.innerHTML.replaceAll("NN", JimGymApp.template) }) // note the parens to make {} an object
    }
    if (evt.detail.cfg.action === "delete") {
        evt.detail.cfg.target = evt.detail.cfg.target.parentElement
        evt.detail.cfg.fetch = () => ({ text: () => "" })
    }
})