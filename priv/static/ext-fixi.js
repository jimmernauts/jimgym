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

  // if the action is "increment-reps/{name}/{index}" or "decrement-reps/{name}/{index}",
  // override the fetch function to instead manipulate the DOM and modify the value of the associated input element.
  if (evt.detail.cfg.action.startsWith("increment-reps/")) {
    let [name, index] = evt.detail.cfg.action.split("/").slice(1);
    let input = evt.detail.cfg.target.parentElement.querySelector(
      `input[name="${name}|reps|${index}"]`
    );
    evt.detail.cfg.fetch = () => ({
      text: () => {
        input.value = parseInt(input.value) + 1;
        evt.detail.cfg.abort();
      },
    });
  }
  if (evt.detail.cfg.action.startsWith("decrement-reps/")) {
    let [name, index] = evt.detail.cfg.action.split("/").slice(1);
    let input = evt.detail.cfg.target.parentElement.querySelector(
      `input[name="${name}|reps|${index}"]`
    );
    evt.detail.cfg.fetch = () => ({
      text: () => {
        input.value = parseInt(input.value) - 1;
        evt.detail.cfg.abort();
      },
    });
  }

  // if the action is "increment-weight/{name}/{index}" or "decrement-weight/{name}/{index}",
  // override the fetch function to instead manipulate the DOM and modify the value of the associated input element.
  if (evt.detail.cfg.action.startsWith("increment-weight/")) {
    let [name, index] = evt.detail.cfg.action.split("/").slice(1);
    let input = evt.detail.cfg.target.parentElement.querySelector(
      `input[name="${name}|weight|${index}"]`
    );
    evt.detail.cfg.fetch = () => ({
      text: () => {
        input.value = parseFloat(input.value) + 0.5;
        evt.detail.cfg.abort();
      },
    });
  }
  if (evt.detail.cfg.action.startsWith("decrement-weight/")) {
    let [name, index] = evt.detail.cfg.action.split("/").slice(1);
    let input = evt.detail.cfg.target.parentElement.querySelector(
      `input[name="${name}|weight|${index}"]`
    );
    evt.detail.cfg.fetch = () => ({
      text: () => {
        input.value = parseFloat(input.value) - 0.5;
        evt.detail.cfg.abort();
      },
    });
  }
});
