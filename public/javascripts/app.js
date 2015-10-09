var selectAll  = document.getElementById('select-all-links');
var checkboxes = document.getElementsByClassName('link-checkbox');

selectAll.addEventListener("click", function(event) {

  if (this.innerText === "click here to select all of the links.") {
    this.innerText = "click here to deselect all of the links.";

    for(var i=0; i<checkboxes.length; i++) {
      checkboxes[i].checked = true;
    }
  } else {
    this.innerText = "click here to select all of the links.";

    for(var i=0; i<checkboxes.length; i++) {
      checkboxes[i].checked = false;
    }
  }
});
