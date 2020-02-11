using GeneradorEnrutador.BusinessLogic;
using System.Collections.Generic;
using System.Web.Http;
using CT.Common.Models;
using CT.Common.Utilities;
using Newtonsoft.Json;

namespace WebApiBiblioteca.Controllers
{
    [Authorize]
    //[AllowAnonymous]
    [RoutePrefix("api/Mecanico")]
    public class MecanicoController : ApiController
    {
        
        [HttpGet]
        [Route("ConsultarMecanicos")]
        public IHttpActionResult Consultar_Mecanicos()
        {
            var IOperacion = GeneradorOperacionBL.InstanciarClase(Enumeradores.clases.MecanicoBL.ToStringAttribute());
            RespuestaDTO response = IOperacion.EjecutarOperacion(Enumeradores.clases.MecanicoBL.ToStringAttribute(), System.Reflection.MethodBase.GetCurrentMethod().Name, null);

            if (response.Exito && response.Mecanicos.IsNullOrEmpty())
            {
                return Ok(new RespuestaDTO()
                {
                    Exito = true,
                    Mensaje = "No se encontro Información",
                });
            }
            else
                return Ok(response);
        }

        [HttpGet]
        [Route("ConsultarMecanicosXid")]
        public IHttpActionResult Consultar_Mecanicos_X_id(string id)
        {
            var IOperacion = GeneradorOperacionBL.InstanciarClase(Enumeradores.clases.MecanicoBL.ToStringAttribute());
            RespuestaDTO response = IOperacion.EjecutarOperacion(Enumeradores.clases.MecanicoBL.ToStringAttribute(), System.Reflection.MethodBase.GetCurrentMethod().Name, new List<string> { id });

            if (response.Exito && response.Mecanicos.IsNullOrEmpty())
            {
                return Ok(new RespuestaDTO()
                {
                    Exito = true,
                    Mensaje = "No se encontro Información",
                });
            }
            else
                return Ok(response);
        }

        [HttpPost]
        [Route("Crear_Mecanico")]
        public IHttpActionResult Crear_Mecanico(MecanicoDTO Mecanico)
        {
            var IOperacion = GeneradorOperacionBL.InstanciarClase(Enumeradores.clases.MecanicoBL.ToStringAttribute());
            RespuestaDTO response = IOperacion.EjecutarOperacion(Enumeradores.clases.MecanicoBL.ToStringAttribute(), System.Reflection.MethodBase.GetCurrentMethod().Name, new List<string> { JsonConvert.SerializeObject(Mecanico) });
            return Ok(response);
        }

        [HttpPost]
        [Route("Actualizar_Mecanico")]
        public IHttpActionResult Actualizar_Mecanico(MecanicoDTO Mecanico)
        {
            var IOperacion = GeneradorOperacionBL.InstanciarClase(Enumeradores.clases.MecanicoBL.ToStringAttribute());
            RespuestaDTO response = IOperacion.EjecutarOperacion(Enumeradores.clases.MecanicoBL.ToStringAttribute(), System.Reflection.MethodBase.GetCurrentMethod().Name, new List<string> { JsonConvert.SerializeObject(Mecanico) });
            return Ok(response);
        }

        [HttpDelete]
        [Route("Eliminar_Mecanico")]
        public IHttpActionResult Eliminar_Mecanico(string id)
        {
            var IOperacion = GeneradorOperacionBL.InstanciarClase(Enumeradores.clases.MecanicoBL.ToStringAttribute());
            RespuestaDTO response = IOperacion.EjecutarOperacion(Enumeradores.clases.MecanicoBL.ToStringAttribute(), System.Reflection.MethodBase.GetCurrentMethod().Name, new List<string> { id });
            return Ok(response);
        }
    }
}