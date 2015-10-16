var selectAll  = document.getElementById('select-all-links') || [];
var checkboxes = document.getElementsByClassName('link-checkbox');
var linkPreviews = document.getElementsByClassName('link-preview');

if (selectAll.length > 0) {
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
}

function updateLinkPreviews() {
  for (var i=0; i<checkboxes.length; i++) {
    var splitValues = checkboxes[i].value.split("|||");
    splitValues[2] = linkPreviews[i].value;
    checkboxes[i].value = splitValues[0] + "|||" + splitValues[1] + "|||" + splitValues[2];
  }
}
