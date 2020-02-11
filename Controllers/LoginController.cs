using CT.Common.Models;
using System.Net;
using System.Web.Http;

namespace WebApiBiblioteca.Controllers
{
    [AllowAnonymous]
    [RoutePrefix("Api/login")]
    public class LoginController : ApiController
    {
        [HttpGet]
        [Route("Ping")]
        public IHttpActionResult Ping()
        {
            return Ok(true);
        }

        [HttpPost]
        [Route("authenticate")]
        public IHttpActionResult Authenticate(LoginRequestDTO login)
        {
            if (login == null)
                throw new HttpResponseException(HttpStatusCode.BadRequest);

            var token = TokenGenerator.GenerateTokenJwt(login.Username);
            return Ok(token);

            //Para no autorizar el Ingreso
            //return Unauthorized();

        }

    }
}
