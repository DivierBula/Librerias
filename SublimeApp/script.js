/**
 * Ejemplo 3 de html2canvas para convertir el HTML de una web
 * a un elemento canvas - Capturar todo el cuerpo del HTML, no solo un div
 * 
 * @author parzibyte
 */
//Definimos el botón para escuchar su click, y también el contenedor del canvas
const $boton = document.querySelector("#btnCapturar"), // El botón que desencadena
  $objetivo =  document.querySelector("#contenedor"), // A qué le tomamos la foto
  $contenedorCanvas = document.querySelector("#contenedorCanvas"); // En dónde ponemos el elemento canvas

// Agregar el listener al botón
$boton.addEventListener("click", () => {

/*const opciones = {
    ignoreElements: elemento => { 
      // Una función que ignora elementos. Regresa true si quieres que
      // el elemento se ignore, y false en caso contrario
      const tipo = elemento.nodeName.toLowerCase();
      // Si es imagen o encabezado h1, ignorar
      if (tipo === "img" || tipo === "h1") {
        return true;
      }
      // Para todo lo demás, no ignorar
      return false
    }
  };
  //console.log(opciones);
*/
const opciones = {
    allowTaint: false, //Machar lienzo
    backgroundColor: "#ff0000",
    removeContainer: true,
    width: $objetivo.offsetWidth,
  	height: $objetivo.offsetHeight,
  	scala: 3

  };


  html2canvas($objetivo,opciones) // Llamar a html2canvas y pasarle el elemento
    .then(canvas => {

 		let context = canvas.getContext('2d')
     	// Desactiva el suavizado
        context.mozImageSmoothingEnabled = false
        context.webkitImageSmoothingEnabled = false
        context.msImageSmoothingEnabled = false
        context.imageSmoothingEnabled = false

      // Cuando se resuelva la promesa traerá el canvas
      $contenedorCanvas.appendChild(canvas); // Lo agregamos como hijo del div

      let enlace = document.createElement('a');
      enlace.download = "Captura.png";
      // Convertir la imagen a Base64
      var imageData = canvas.toDataURL();
      enlace.href = imageData;
      // Hacer click en él
      console.log(imageData.replace(/^data:image\/png/, "data:application/octet-stream"))
      //enlace.click();

    });
});