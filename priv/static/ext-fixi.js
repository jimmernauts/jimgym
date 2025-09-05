let JimGymApp = {};

document.addEventListener("fx:config", (evt) => {
  // if the fx:action target URL is an id of an element, override the fetch function to return the innerHTML of that element
  template = document.getElementById(evt.detail.cfg.action);
  if (template) {
    JimGymApp.template = JimGymApp.template ?? 0;
    JimGymApp.template++;
    evt.detail.cfg.fetch = () => ({
      text: () => template.innerHTML.replaceAll("NN", JimGymApp.template),
    }); // note the parens to make {} an object
  }
  // if the action is "delete", override the fetch function to return an empty string.
  // this is used to delete an element from the DOM.
  if (evt.detail.cfg.action === "delete") {
    evt.detail.cfg.target = evt.detail.cfg.target.parentElement;
    evt.detail.cfg.fetch = () => ({ text: () => "" });
  }

  // TODO: if the action is "increment" or "decrement", override the fetch function to
  // instead manipulate the DOM and modify the value of the associated input element.
});
