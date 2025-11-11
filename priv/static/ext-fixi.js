let JimGymApp = {};

document.addEventListener("fx:config", (evt) => {
  // if the fx:action target URL is an id of an element, override the fetch function to return the innerHTML of that element.
  // expects there to be an 'index' of -99 in the template which gets replaced with the next available index.
  template = document.getElementById(evt.detail.cfg.action);
  if (template) {
    JimGymApp.template_insertions = JimGymApp.template_insertions ?? 0;
    JimGymApp.template_insertions++;
    evt.detail.cfg.fetch = () => ({
      text: () =>
        template.innerHTML.replaceAll("-99", JimGymApp.template_insertions),
    });
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

  // if the action is "clone/{name}/{index}", override the fetch function to instead manipulate the DOM and insert a new exercise row, while updating the index of the new row.
  if (evt.detail.cfg.action.startsWith("clone/")) {
    console.log("clone event", evt.detail.cfg);
    let [name, index] = evt.detail.cfg.action.split("/").slice(1);
    evt.detail.cfg.fetch = () => ({
      text: () => {
        // Compute next index as max existing index for this exercise name
        const allNameInputs = document.querySelectorAll(
          `input[name^="${name}|name|"]`
        );
        let maxIndex = -1;
        allNameInputs.forEach((el) => {
          const parts = el.name.split("|");
          const maybeIdx = parseInt(parts[2]);
          if (!Number.isNaN(maybeIdx)) maxIndex = Math.max(maxIndex, maybeIdx);
        });
        const new_index = maxIndex + 1;

        // Clone current row and update all inputs for this exercise name to new index
        const new_row = evt.detail.cfg.target.cloneNode(true);
        new_row
          .querySelectorAll(`input[name^="${name}|"][name$="|${index}"]`)
          .forEach((input) => {
            const parts = input.name.split("|");
            parts[2] = String(new_index);
            input.name = parts.join("|");
          });
        new_row.id = "exercise|" + name + "|" + new_index;
        return new_row.outerHTML;
      },
    });
  }
});
