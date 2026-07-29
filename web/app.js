const hashButton = document.querySelector("#copyHash");
const copyState = document.querySelector("#copyState");

hashButton.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(hashButton.textContent.trim());
    copyState.textContent = "CHECKSUM COPIED";
  } catch {
    copyState.textContent = "SELECT AND COPY THE CHECKSUM";
  }
  window.setTimeout(() => { copyState.textContent = ""; }, 2200);
});
