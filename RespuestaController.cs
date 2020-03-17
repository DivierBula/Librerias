using System.Web.Mvc;
using ModelCobertura;
using System.Web;
using System;

namespace ConsultaCobertura.Controllers
{
    public class RespuestaController : Controller
    {
        // GET: Respuesta
        public ActionResult Respuesta()
        {
            string valorCookie = System.Web.HttpContext.Current.Session["sessionCookie"].ToString();
            ViewBag.valorCookie = valorCookie; //(modelo.RespuestaDTO != null && modelo.RespuestaDTO.Descripcion != null ? modelo.RespuestaDTO.Descripcion : "");
            return View("Respuesta");
        }               
        
        public ActionResult consultarCookie()
        {
            string valor = Request.Cookies["respuestaCobertura"].Value;
            return Json(new { responseText = "OK", valorCookie = valor});
        } 
    }
}