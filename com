import { Component, OnInit } from '@angular/core';
import { Model } from './entidades';
import { LoginService } from 'src/app/core/services/auth/login.service';
import { ApiService } from 'src/app/core/services/api/api.service';
import { Validaciones } from 'src/app/sip/tratamiento/anotaciones/validaciones';
import { ScriptsService } from 'src/app/core/services/scripts/scripts.service';
import { GlobalService } from 'src/app/core/services/global/global.service';
import { DatePipe } from '@angular/common';

declare var $: any;
declare var swal: any;

const CONST_LISTADINAMICA = "ListaDinamicasFull";
const CONST_AD_ESTADOS = "AD_ESTADOS";
const CONST_POR_APROBAR = "PA";

@Component({
  selector: 'app-anotaciones',
  templateUrl: './anotaciones.component.html',
  styleUrls: ['./anotaciones.component.scss']
})
export class AnotacionesComponent implements OnInit {

  model = new Model();

  pad(n) { return (n < 10 ? '0' + n : n); }

  constructor(private login: LoginService, private api: ApiService, private validaciones: Validaciones, private global: GlobalService, private Utilidades: ScriptsService, public datePipe: DatePipe) {
    this.model.d = new Date();
    this.model.user = this.login.getCurrentUser();
    this.getListas();
    this.filter(this.model.pagFilter, this.model.textFilter);
    //condicion para abrir el modal cuando viene vacio de otra pagina
    setTimeout(() => {
      if (JSON.parse(localStorage.getItem('ModalVacio')) != 0 && JSON.parse(localStorage.getItem('ModalVacio')) != undefined) {
        if (JSON.parse(localStorage.getItem('ModalVacio')) == "-1") {
          this.openAnotacion(true);
        }
        else {
          this.obtenerAnotacionIndvidual(Number(JSON.parse(localStorage.getItem('ModalVacio'))), true);
        }
        localStorage.setItem("ModalVacio", "0");
      }
    }, 1000);

  }


  ngOnInit() {
  }

  search(filter: string) {

    if (this.model.searchType) {
      if (filter.length > 1) {
        this.model.textFilter = filter;
        if (!this.model.loadingitem) {
          this.filter(this.model.pagFilter, this.model.textFilter);
        }
      } else {
        this.model.textFilter = null;
      }
    } else {
      if (filter.length == 0) {
        this.model.varhistorial = this.model.varhistorialTemp;
      } else {
        this.model.varhistorial = this.model.varhistorialTemp.filter(item => {
          if (item.consecutivo.toString().toLowerCase().indexOf(filter.toLowerCase()) !== -1 ||
            item.descripcion.toString().toLowerCase().indexOf(filter.toLowerCase()) !== -1 ||
            item.fecha.toString().toLowerCase().indexOf(filter.toLowerCase()) !== -1) {
            return true;
          }
          return false;
        });
      }
    }
  }

  toggleSearch() {
    this.model.searchType = !this.model.searchType;
    this.model.pagFilter = 0;
    this.model.textFilter = null;
    this.model.inputSearch = "";
    this.model.varhistorialTemp = [];
    this.model.varhistorial = [];
    if (!this.model.searchType) {
      this.filter(this.model.pagFilter, '');
    }
  }

  filter(data: number, text: string) {
    this.model.loadingitem = true;
    this.api.GetAnotaciones({ dataFilter: data, dataText: text }).subscribe(data => {
      this.model.loadingitem = false;
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        console.log(response.result);
        this.model.varhistorial = response.result;
        this.model.varhistorialTemp = response.result;
      }
    });
  }

  private obtenerAnotacionIndvidual(anotacion_id: number, IsLectura: any) {
    this.api.GetAnotacionesIndividual({ id: anotacion_id }).subscribe(data => {
      this.model.loadingitem = false;
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.openDetalle(response.result[0], true);
      } else {
        swal({
          title: 'Error',
          text: 'La anotacion no fue encontrada.',
          allowOutsideClick: false,
          showConfirmButton: true,
          type: 'warning',
        });
      }
    });
  }

  /** OBTIENE LISTAS DINAMICAS */
  getListas() {
    setTimeout(() => {
      var listas = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA));
      this.GetListaMisiones();
      this.GetCategorias();
      this.GetListaActividades();
      this.GetListaInOrganizaciones();
      this.GetListaSubestructura();
      this.GetListaInOrganizacionesIlegales();
      this.ObtenerBienesElementos();
      this.ObtenerUnidadInteligencia();
      this.GetAnotacionesMunicipios();

      this.model.lstActivaIlicita = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "FT_ACTIVIDAD_ILICITA").detalle;
      this.model.lstTipoPersona = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_TIPIFICACION").detalle.filter(y => y.atributo1 == 'H' || y.id == 0);
      this.model.lstRol = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_HECHO_ROL").detalle;
      this.model.lstTipoSenial = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "AD_TIPO_SENIAL").detalle;
      this.model.lstTipoDesmov = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_TIPO_DESMOVILIZACION").detalle;
      this.model.listPropietario = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_HECHO_PROPIETARIO").detalle;
      this.model.listPropietarioDet = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_HECHO_PROPIETARIO").detalle;
      this.model.listPais = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "AD_PAISES").detalle;
      this.model.listPais.forEach(x=> x.nombre = x.detalle);
      this.model.listNacionalidad = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "AD_NACIONALIDAD").detalle;
      this.model.listNacionalidad.forEach(x=> x.nombre = x.detalle);
      this.model.listTipoDocumento = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_TIPO_DOCUMENTO").detalle;
      this.model.listaEstados = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == "TR_CAPA_ESTADOS").detalle;

      for (let i = 0; i < listas.length; i++) {
        $("." + listas[i].nombre).html("");
        for (let j = 0; j < listas[i].detalle.length; j++) {
          $("." + listas[i].nombre).append('<option value=' + listas[i].detalle[j].id + '>' + listas[i].detalle[j].detalle + '</option>');
        }
      }
    }, 900);
  }

  public GetListaMisiones() {
    this.api.GetLstaMisionesAnotaciones({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.ListMisiones = response.result;
      }
    });
  }

  public GetCategorias() {
    this.api.GetlistaCategoriasAnotaciones({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.ListCategorias = response.result;
      }
    });
  }

  public GetListaActividades() {
    this.api.GetListaActividadesAnotaciones({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.ListaActividades = response.result;
      }
    });
  }

  openAnotacion(IsLectura: any) {
    this.model.modal = true;
    if (IsLectura == false) {
      this.model.varAnotaciones = new Model().varAnotaciones;
      this.model.varRecoleccion = new Model().varRecoleccion;
      this.model.steps.map(x => x.active = false);
      this.model.steps[0].active = true;
      this.model.IsLectura = IsLectura;
      this.model.varAnotaciones.anotacion_id = 0;
      this.model.varActividad = [];
      this.model.varOrgan = [];
      this.model.varOrgan2 = [];
      this.model.varComp = [];
      this.model.tipoIdent = false;
      this.model.varResultBien = [];
      this.model.varMovim = [];
    }
    this.obtenerNumMostrar();
  }

  openDetalle(anotacion: any, IsLectura: any) {
    this.model.modal = true;
    anotacion.fecha = this.Utilidades.parseDate(anotacion.fecha, false);
    this.model.varAnotaciones = anotacion;
    this.model.anotacion_id = anotacion.anotacion_id;
    this.model.IsLectura = IsLectura;
    this.model.steps.map(x => x.active = false);
    this.model.steps[0].active = true;
    this.ObtenerRecoleccionesAnotacion(anotacion.anotacion_id);
    this.ObtenerDatosStep7(anotacion.anotacion_id);
    this.ObtenerAnotacionesActividad(anotacion.anotacion_id);
    this.GetAnotacionesCorgas(anotacion.anotacion_id);
    this.GetAnotacionesCobios(anotacion.anotacion_id);
    this.GetAnotacionesMigratorios(anotacion.anotacion_id);
    this.obtenerNumMostrar();
  }

  public ObtenerRecoleccionesAnotacion(anotacion_id: Number) {
    this.api.GetRecoleccionesAnotaciones({ id: anotacion_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        response.result.forEach(element => {
          element.fecha = this.Utilidades.parseDate(element.fecha, false);
        });
        this.model.varRecoleccion = response.result;
      }
    });
  }

  editarAnotacion(anotacion: any, IsLectura: any) {
    this.model.modal = true;
    anotacion.fecha = this.Utilidades.parseDate(anotacion.fecha, false);
    this.model.varAnotaciones = anotacion;
    this.model.anotacion_id = anotacion.anotacion_id;
    this.model.IsLectura = IsLectura;
    this.model.steps.map(x => x.active = false);
    this.model.steps[anotacion.step_system].active = true;
    this.obtenerNumMostrar();
    this.CargarStepAnterior(0);
  }

  /** Encargado de abir modal vacio para crear un cobios */
  openModalCobios() {
    window.open(this.api.urlmodel + 'modal/vacio/cobios', 'Cobios', this.Utilidades.GetModalVio());
    localStorage.setItem("ModalVacio", "-1");
  }

  /** Encargado de abir modal vacio para crear un corgas */
  openModalCorgas() {
    window.open(this.api.urlmodel + 'modal/vacio/corgas', 'Corgas', this.Utilidades.GetModalVio());
    localStorage.setItem("ModalVacio", "-1");
  }

  /** Encargado de abir modal vacio para un vinculo un corgas */
  openModalVinculos() {
    window.open(this.api.urlmodel + 'modal/vacio/vinculos', 'Vinculos', this.Utilidades.GetModalVio());
    localStorage.setItem("ModalVacio", "-1");
  }

  openModalBienes() {
    window.open(this.api.urlmodel + 'modal/vacio/inventario', 'Inventario', this.Utilidades.GetModalVio());
    localStorage.setItem("ModalVacio", "-1");
  }

  InicializarPeriodo(recoleccion: any, i: any) {
    let th = recoleccion;
    let ths = this;
    $('.datepicker-range' + i).datepicker({
      clearButton: true,
      onSelect: function (data) {
        let fechas = data.split(' - ');
        let t = [];
        th.fecha_inicio = "";
        th.fecha_termino = "";

        if (fechas[0] != undefined) {
          th.fecha_inicio = fechas[0];
        }

        t = [];
        if (fechas[1] != undefined) {
          th.fecha_termino = fechas[1];
        }

        th.periodo = fechas[0];
        if (th.fecha_termino != "")
          th.periodo += " - " + fechas[1];
      },
      onHide: function (data) {
        ths.ObtenerListaConsecutivo(th.fecha_inicio, th.fecha_termino, i);
      }

    });
  }

  public ObtenerListaConsecutivo(fechaini: any, fechafin: any, index: any) {
    let jsonconsecutivo = {
      "dateStart": fechaini,
      "dateEnd": fechafin
    };
    this.api.GetListaConsuecutivoAnotaciones(jsonconsecutivo).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listconsecutivo[index] = response.result;
      }
    });
  }

  private ObtenerUnidadInteligencia() {
    this.api.GetAnotacionesUnidadInteligencia({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listUnidades = response.result;
      }
    })
  }

  private ObtenerDependencias(unidad_id: number) {
    this.api.GetAnotacionesDependencia({ id: unidad_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listDependencia = response.result;
      }
    });
  }

  private ObtenerFuncionarios(Dependencia_id: number) {
    this.api.GetAnotacionesFuncionarios({ id: Dependencia_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listFuncionarios = response.result;
      }
    });
  }

  saveConsecutivo(index: any) {
    setTimeout(() => {
      this.model.inputfrom = "consecutivo";
      this.model.indexfrom = index;
      this.model.datosmodal = this.model.listconsecutivo[index];
      this.model.select1modal = true;
      this.model.sizeModel = 'mini-modal'
    }, 1200);
  }

  SaveMt() {
    this.model.ListMisiones.forEach(x => {
      x.nombre = x.num_mision;
    });
    this.model.inputfrom = "mt";
    this.model.datosmodal = this.model.ListMisiones;
    this.model.selectmodal = true;
    this.model.sizeModel = 'medium-modal'
  }

  SaveCategorias() {
    this.model.ListCategorias.forEach(x => {
      x.nombre = x.categoria;
    });
    this.model.inputfrom = "categoria";
    this.model.datosmodal = this.model.ListCategorias;
    this.model.selectmodal = true;
    this.model.sizeModel = 'medium-modal'
  }

  saveUnidad() {
    this.model.inputfrom = "unidad";
    this.model.datosmodal = this.model.listUnidades;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }

  saveDependencia() {
    this.model.inputfrom = "dependencia";
    this.model.datosmodal = this.model.listDependencia;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }

  saveFuncionarios() {
    this.model.inputfrom = "funcionarios";
    this.model.datosmodal = this.model.listFuncionarios;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }

  /** carga toda la informacion posible por seleccionar*/
  saveSubEstructura(index: number) {
    this.model.inputfrom = "unidad-destino-subEstructura";
    this.model.indexfrom = index;
    this.model.datosmodal = this.model.listsubestructura;
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }

  /**
  * carga toda la informacion posible por seleccionar
  * @param index indice donde se guardara el cargue
  */
  saveEstructura(index: number) {
    this.model.inputfrom = "unidad-destino-estructura";
    this.model.indexfrom = index;
    this.model.datosmodal = this.model.listestructura[index];
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }

  /**
  * carga toda la informacion posible por seleccionar
  * @param index indice donde se guardara el cargue
  */
  saveGrupos(index: number) {
    this.model.inputfrom = "unidad-destino-grupo";
    this.model.indexfrom = index;
    this.model.datosmodal = this.model.listgrupo[index];
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }
  saveClase()
  {
    this.model.inputfrom = "Clase-Bienes";
    this.model.datosmodal = this.model.listClase;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }
  saveClaseDet()
  {
    this.model.inputfrom = "Clase-Bienes-det";
    this.model.datosmodal = this.model.listClaseDet;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }
  saveMarca()
  {
    this.model.inputfrom = "Marca-Bienes";
    this.model.datosmodal = this.model.listMarca;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }
  saveMarcaDet()
  {
    this.model.inputfrom = "Marca-Bienes-det";
    this.model.datosmodal = this.model.listMarcaDet;
    this.model.selectmodal = true;
    this.model.sizeModel = 'small-modal'
  }

  SaveOrganizacion() {
    this.model.inputfrom = "organizaciones";
    this.model.datosmodal = this.model.listOrganizacionesIlegales;
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }
  savePaises(destino: string, index: number)
  {
    this.model.inputfrom = destino;
    this.model.datosmodal = this.model.listPais;
    this.model.indexfrom =  index;
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }
  saveMunicipios(index: number)
  {
    this.model.inputfrom = "Municipio";
    this.model.datosmodal = this.model.listMunicipios;
    this.model.indexfrom =  index;
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }
  saveNacionalidad(index: number)
  {
    this.model.inputfrom = "Nacionalidad";
    this.model.datosmodal = this.model.listNacionalidad;
    this.model.indexfrom =  index;
    this.model.selectmodal = true;
    this.model.sizeModel = 'mini-modal'
  }

  datafrom(data: any, type: number) {
    this.model.datosmodal = [];
    if (type == 1) this.model.selectmodal = false;
    else if (type == 2) this.model.select1modal = false;

    if (this.model.inputfrom == "mt") {
      this.model.varAnotaciones.mision_trabajo_id = data.mision_trabajo_id;
      this.model.varAnotaciones.num_mision = data.nombre;
    }

    if (this.model.inputfrom == "categoria") {
      this.model.varAnotaciones.categoria_id = data.categoria_id;
      this.model.varAnotaciones.categoria = data.nombre;
    }

    if (this.model.inputfrom == "consecutivo") {
      this.model.varRecoleccion[this.model.indexfrom].contenido_id = data.contenido_id;
      this.model.varRecoleccion[this.model.indexfrom].fecha = this.datePipe.transform(data.fecha, "yyyy-MM-dd");
      this.model.varRecoleccion[this.model.indexfrom].consecutivo = data.consecutivo;
      this.model.varRecoleccion[this.model.indexfrom].descripcion = data.descripcion;
    }
    else if (this.model.inputfrom == "unidad") {
      this.model.varDetalle.unidad_id = data.id;
      this.model.varDetalle.unidad = data.nombre;
      this.ObtenerDependencias(data.id);
    }
    else if (this.model.inputfrom == "dependencia") {
      this.model.varDetalle.dependencia_id = data.id;
      this.model.varDetalle.dependencia = data.nombre;
      this.ObtenerFuncionarios(data.id);
    }
    else if (this.model.inputfrom == "funcionarios") {
      this.model.varDetalle.funcionario_id = data.id;
      this.model.varDetalle.funcionario = data.nombre;
      this.model.varDetalle.grado = data.grado;
    }
    else if (this.model.inputfrom == "unidad-destino-subEstructura") {
      this.model.varOrgan[this.model.indexfrom].subestructura_id = data.subestructura_id;
      this.model.varOrgan[this.model.indexfrom].subestructura = data.nombre;
      this.model.varOrgan[this.model.indexfrom].estructura_id = 0;
      this.model.varOrgan[this.model.indexfrom].estructura = "Seleccione";
      this.model.varOrgan[this.model.indexfrom].grupo_id = 0;
      this.model.varOrgan[this.model.indexfrom].grupo = "Seleccione";
      this.GetListaEstructura(data.subestructura_id, this.model.indexfrom);

    } else if (this.model.inputfrom == "unidad-destino-estructura") {
      this.model.varOrgan[this.model.indexfrom].estructura_id = data.estructura_id;
      this.model.varOrgan[this.model.indexfrom].estructura = data.nombre;
      this.model.varOrgan[this.model.indexfrom].grupo_id = 0;
      this.model.varOrgan[this.model.indexfrom].grupo = "Seleccione";
      this.GetListaGrupo(data.estructura_id, this.model.indexfrom);

    } else if (this.model.inputfrom == "unidad-destino-grupo") {
      this.model.varOrgan[this.model.indexfrom].grupo_id = data.grupo_id;
      this.model.varOrgan[this.model.indexfrom].grupo = data.nombre;
    }else if (this.model.inputfrom ==  "Clase-Bienes") {
      this.model.varBusquedaDetalle.clase = data.id;
      this.changeClaseBien();
    }else if (this.model.inputfrom ==  "Marca-Bienes") { 
      this.model.varBusquedaDetalle.marca = data.id;
    }else if (this.model.inputfrom ==  "Clase-Bienes-det") {
      this.model.varDetalle.clase = data.id;
      this.changeClaseBienDet(false);
    }else if (this.model.inputfrom ==  "Marca-Bienes-det") {
      this.model.varDetalle.marca = data.id;
      this.changeMarcaBienDet();
    }else if (this.model.inputfrom ==  "organizaciones") {
      this.model.varDetalle.organizacion_id = data.organizacion_id;
      this.model.varDetalle.organizacion = data.nombre;
      this.changeOrganizacionTres(false)
    }else if (this.model.inputfrom ==  "PaisOrigen") {
      this.model.varMigrat[this.model.indexfrom].pais_origen_id = data.id;
      this.model.varMigrat[this.model.indexfrom].pais_origen = data.nombre;
    }
    else if (this.model.inputfrom ==  "PaisDestino") {
      this.model.varMigrat[this.model.indexfrom].pais_destino_id = data.id;
      this.model.varMigrat[this.model.indexfrom].pais_destino = data.nombre;
    }
    else if (this.model.inputfrom ==  "Municipio") {
      this.model.varMigrat[this.model.indexfrom].municipio_contacto_id = data.municipio_id;
      this.model.varMigrat[this.model.indexfrom].municipio_contacto = data.nombre;
    }
    else if (this.model.inputfrom ==  "Nacionalidad") {
      this.model.varMigrat[this.model.indexfrom].nacionalidad_id = data.id;
      this.model.varMigrat[this.model.indexfrom].nacionalidad = data.nombre;
    }
  }

  closeAnotacionModal(bol: any) {
    this.model.modal = bol;
  }

  openAprobar() {
    this.model.aprobarModal = true;
  }

  closeAprobarModal(bol: any) {
    this.model.aprobarModal = bol;
  }

  nextPage(num: number) {
    let response: any = { error: false, error_msg: '' };
    this.model.varAnotaciones.step_system = (num >= 7) ? 6 : num;

    if (num > (this.model.steps.filter(x => x.active == true)[0].num - 1)) {
      //General
      if (num >= 1) {
        response = this.validaciones.ValidacionesStepUno(this.model);
        if (response.error)
          num = 0;
        else {
          this.model.varAnotaciones.Recoleccion = this.model.varRecoleccion;
          this.CrearAnotacionesStep1(
            this.model.varAnotaciones.NuevoRegistro == true ? this.model.varAnotaciones : null
          );
          this.ActualizarAnotacionesStep1(
            this.model.varAnotaciones.NuevoRegistro != true ? this.model.varAnotaciones : null
          );
        }
      }

      //Territorial no lleva
      
      //Componente organico
      if (num >= 3) {
        response = this.validaciones.ValidacionesStepCuatro(this.model);
        if (response.error)
          num = 2;
        else if (num == 3 && this.model.varAnotaciones.activarOrganico) {
          this.model.varOrgan2.forEach(x => this.model.varOrgan.push(x));
          this.CrearAnotacionesStep3(
            this.model.varOrgan.filter(x => x.NuevoRegistro == true)
          );
          this.ActualizarAnotacionesStep3(
            this.model.varOrgan.filter(x => x.NuevoRegistro != true)
          );
        }
      }
      //Componente biografico
      if (num >= 4) {
        response = this.validaciones.ValidacionesStepCinco(this.model);
        if (response.error)
          num = 3;
        else if (num == 4 && this.model.varAnotaciones.activarBiografico) {

          let request = [];
          let requestAct = [];
          this.model.varComp.forEach(x => {
            x.anotacion_id = this.model.anotacion_id;
            x.tipo_persona_id = Number(x.tipo_persona_id);
            x.rol_id = Number(x.rol_id);
            x.num_identificacion = String(x.num_identificacion);
            if (x.NuevoRegistro == true) {
              request.push(x);
            } else {
              requestAct.push(x);
            }
          });
          this.model.varComp2.forEach(x => {
            x.anotacion_id = this.model.anotacion_id;
            x.pralias_id = Number(x.pralias_id);
            x.organizacion_id = Number(x.organizacion_id);
            x.rol_id = Number(x.rol_id);
            x.actividad_delictiva_id = Number(x.actividad_delictiva_id);
            if (x.NuevoRegistro == true) {
              request.push(x);
            } else {
              requestAct.push(x);
            }
          });
         
          this.CrearAnotacionesStep4(request);
          this.ActualizarAnotacionesStep4(requestAct);
        }
      }
      if(num==5)
      {
        this.buscarBienes()
      }

      //Mov. migratorios No lleva
      
      //Georreferenciación
      if (num == 7) {
        this.ObtenerDatosStep7(this.model.anotacion_id);
        setTimeout(() => {
          swal({
            text: "La anotación fue guardada exitosamente",
            allowOutsideClick: false,
            showConfirmButton: true,
            type: 'success',
          }).then(result=>{
            this.filter(this.model.pagActual,this.model.inputSearch);
          });
        }, 1000);
      }
      
      

      //Notificacion de aprobación!!
      if (num == 8) {
          this.NotificarAprobacion();
      }

      if (response != undefined && response.error) {
        swal({
          title: 'Error',
          text: response.error_msg,
          allowOutsideClick: false,
          showConfirmButton: true,
          type: 'warning',
        });
      }
    }
    else {
      this.CargarStepAnterior(num);
    }
    if (!response.error && num < 7) {
      this.nextPageDetalle(num);
    }
  }

  nextPageDetalle(num: number) {
    if(num==4)
      this.buscarBienes();

    let pass = true;
    while (pass) {
      if (this.model.steps[num].ver) {
        this.model.steps.map(x => x.active = false);
        this.model.steps[num].active = true;
        pass = false;
      } else {
        num += 1;
      }
    }
  }

  CargarStepAnterior(num: number) { 
    if (this.model.anotacion_id != null) {
      if (num <= 0) { // General
        this.ObtenerRecoleccionesAnotacion(this.model.anotacion_id);
      }
      if (num <= 1) { // Componente Territorial
        this.ObtenerAnotacionesActividad(this.model.anotacion_id);
      }
      if (num <= 2) { // Componente Organica
        this.GetAnotacionesCorgas(this.model.anotacion_id);
      }
      if (num <= 3) { // Componente Biografico
        this.GetAnotacionesCobios(this.model.anotacion_id);
      }
      if (num <= 4) { // Bienes
        this.buscarBienes();
      }
      if (num <= 5) { // Mov. Migratorios
        this.GetAnotacionesMigratorios(this.model.anotacion_id);
      }
      if (num <= 6) { // Georreferencia
        this.ObtenerDatosStep7(this.model.anotacion_id);
      }
    }
  }

  public ObtenerDatosStep7(anotacion_id: any) {
    this.api.GetAnotacionesMultimedia({ "id": anotacion_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        response.result.forEach(res => { if (res.url_adjunto != "") res.nombreMultimedia = (res.url_adjunto.split('/')[res.url_adjunto.split('/').length - 1]).substring(0, 20) + "..."; });
        this.model.varMulti = response.result;
      }
    });

    this.api.GetAnotacionesTerritorios({ "id": anotacion_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varGeo = response.result;
      }
    });
  }

  /**
  * Se crean las anotaciones del step 1
  * @param requestAnotaciones
  */
  private CrearAnotacionesStep1(requestAnotaciones: any) {
    if (requestAnotaciones != null) {
      requestAnotaciones.mision_trabajo_id = Number(requestAnotaciones.mision_trabajo_id);
      requestAnotaciones.categoria_id = Number(requestAnotaciones.categoria_id);

      requestAnotaciones.Recoleccion.forEach(x => {
        x.contenido_id = Number(x.contenido_id)
      });
      this.api.CrearAnotaciones(requestAnotaciones).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.anotacion_id = Number(response.id);
          this.model.varAnotaciones.anotacion_id = Number(response.id);
          this.model.varAnotaciones.consecutivo = Number(response.codigo);
          this.model.varAnotaciones.NuevoRegistro = false;
          this.ObtenerDatosStep7(this.model.anotacion_id);
          this.ObtenerRecoleccionesAnotacion(this.model.anotacion_id);
          swal({
            text: response.mensaje,
            showConfirmButton: true,
            type: 'success',
            confirmButtonText: 'Aceptar'
          }).then(result => {
            this.filter(this.model.pagActual, this.model.inputSearch);
          });
        }
      });
    }
  }

  /**
  * Se actualizann as anotaciones step 1
  * @param requestAnotaciones Medios del step 2
  */
  private ActualizarAnotacionesStep1(requestAnotaciones: any) {
    if (requestAnotaciones != null) {
      requestAnotaciones.mision_trabajo_id = Number(requestAnotaciones.mision_trabajo_id);
      requestAnotaciones.categoria_id = Number(requestAnotaciones.categoria_id);
      this.api.ActualizarAnotaciones(requestAnotaciones).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.anotacion_id = Number(response.id);
          this.ObtenerDatosStep7(this.model.anotacion_id);
          this.ObtenerRecoleccionesAnotacion(this.model.anotacion_id);
        }
      });
    }
  }

  // private CrearAnotacionesStep2(requestTerri: any, requestMulti: any) {
  //   if (requestTerri != null) {
  //     this.api.CrearAnotacionesTerritorios(requestTerri).subscribe(data => { this.api.ProcesarRespuesta(data); });;
  //   }
  //   if (requestMulti != null) {
  //     this.api.CrearAnotacionesMultimedias(requestMulti).subscribe(data => { this.api.ProcesarRespuesta(data); });;
  //   }
  // }

  // private ActualizarAnotacionesStep2(requestTerri: any, requestMulti: any) {
  //   if (requestTerri != null) {
  //     this.api.ActualizarAnotacionesTerritorios(requestTerri).subscribe(data => { this.api.ProcesarRespuesta(data); });;
  //   }
  //   if (requestMulti != null) {
  //     this.api.ActualizarAnotacionesMultimedias(requestMulti).subscribe(data => { this.api.ProcesarRespuesta(data); });;
  //   }
  // }

  private CrearAnotacionesStep2(requestActividad: any) {
    if (requestActividad.length > 0) {
      requestActividad.forEach(element => {
        element.actividad_id = Number(element.actividad_id);
        element.anotacion_id = Number(this.model.anotacion_id);
        element.estados = Number(element.estados);
        if(element.fecha_fin =='' || element.fecha_fin == undefined)
          delete element.fecha_fin;

        this.api.CrearAnotacionesActividades(element).subscribe(data => {
          let response: any = this.api.ProcesarRespuesta(data);
          if (response.tipo == 0) {
            this.model.activTeriModal = true;
            element.anotacion_actividad_id =  Number(response.id);
            this.ObtenerAnotacionesActividadObs(Number(response.id));
          }
        })
      });
    }
  }

  private CrearAnotacionesStep3(requestCorgas: any) {
    if (requestCorgas.length > 0) {
      requestCorgas.forEach(element => {
        element.anotacion_id = Number(this.model.anotacion_id);
        element.organizacion_id = Number(element.organizacion_id);
        element.subestructura_id = Number(element.subestructura_id);
        element.estructura_id = Number(element.estructura_id);
        element.grupo_id = Number(element.grupo_id);
      });
      this.api.CrearAnotacionesCorgas(requestCorgas).subscribe(data => { this.api.ProcesarRespuesta(data); });;
    }
  }

  private ActualizarAnotacionesStep3(requestCorgas: any) {
    if (requestCorgas.length > 0) {
      requestCorgas.forEach(element => {
        element.anotacion_id = Number(this.model.anotacion_id);
        element.subestructura_id = Number(element.subestructura_id);
        element.estructura_id = Number(element.estructura_id);
        element.grupo_id = Number(element.grupo_id);
      });
      this.api.ActualizarAnotacionesCorgas(requestCorgas).subscribe(data => { this.api.ProcesarRespuesta(data); });;
    }
  }

  private CrearAnotacionesStep4(requestCobios: any) {
    if (requestCobios.length>0) {
      this.api.CrearAnotacionesCobios(requestCobios).subscribe(data => { this.api.ProcesarRespuesta(data); });;
    }
  }

  private ActualizarAnotacionesStep4(requestCobios: any) {
    if (requestCobios.length>0) {
      this.api.ActualizarAnotacionesCobios(requestCobios).subscribe(data => { this.api.ProcesarRespuesta(data); });;
    }
  }

  private CrearAnotacionesStep6(requestMigratorio: any) {
    if (requestMigratorio.length > 0) {
      requestMigratorio.forEach(element => {
        element.anotacion_id = Number(this.model.anotacion_id);
      });
      this.api.CrearAnotacionesMigratorios(requestMigratorio).subscribe(data => {
        let response = this.api.ProcesarRespuesta(data);
        if(response.tipo ==0)
        {
          requestMigratorio[0].anotacion_migratorio_id = Number(response.id);
          requestMigratorio[0].NuevoRegistro= false;
          this.model.migratModal = true;
          this.model.varMigrat=[];
          this.GetAnotacionesMigratoriosDetalle(Number(response.id));
        }
      });
    }
  }

  private ActualizarAnotacionesStep6(requestMigratorio: any) {
    if (requestMigratorio.length > 0) {
      requestMigratorio.forEach(element => {
        element.anotacion_id = Number(this.model.anotacion_id);
      });
      this.api.ActualizarAnotacionesMigratorios(requestMigratorio).subscribe(data => {
        let response = this.api.ProcesarRespuesta(data);
        if(response.tipo ==0)
        {
          this.model.varMigratorioDetalle.anotacion_migratorio_id = Number(response.id);
          this.model.migratModal = true;
          this.model.varMigrat=[];
          this.GetAnotacionesMigratoriosDetalle(Number(response.id));
        }
      });
    }
  }

  openActivTerri(actividad: any) {

    let response = this.validaciones.ValidacionesStepTres(this.model);
    if (response.error) {
      swal({
        title: 'Error',
        text: response.error_msg,
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'warning',
      });
    } else {
      this.model.varActividadObs = [];
      setTimeout(() => { this.model.activTeriModal = true; }, 500);
      this.model.actividad = this.model.ListaActividades.filter(x=> x.actividad_id == actividad.actividad_id)[0].actividad
      this.CrearAnotacionesStep2([actividad]);
     }
     
  }

  GuardarAtributosTerritorio() {
    this.model.varActividadObs.forEach(request => {
      this.api.CrearAnotacionesActividadesObs(request).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          request.anotacion_activobs_id = Number(response.id);
          this.model.activTeriModal = false;
        }
      });
    });
  }


  //traer anotaciones actividades
  private ObtenerAnotacionesActividad(anotacion_id: any) {
    this.api.GetAnotacionesActividades({ "id": anotacion_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        response.result.forEach(x => {
          x.NuevoRegistro = false;
          if (x.fecha_inicio == '0001-01-01T00:00:00') {
            delete x.fecha_inicio;
          } else {
            x.fecha_inicio = this.datePipe.transform(x.fecha_inicio, "yyyy-MM-dd");
          }
          if (x.fecha_fin == '0001-01-01T00:00:00') {
            delete x.fecha_fin;
          } else {
            x.fecha_fin = this.datePipe.transform(x.fecha_fin, "yyyy-MM-dd");
          }
          this.changeactividad(x, true);
        });
        this.model.varActividad = response.result;

      }
    });
  }

  //trae los atributos con observaciones
  private ObtenerAnotacionesActividadObs(actividad_anotacion_id: any) {
    this.api.GetAnotacionesActividadesObs({ id: actividad_anotacion_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varActividadObs = response.result;
      }
    });
  }

  closeActivTerriModal(bol: any) {
    this.model.activTeriModal = bol;
  }

  addTerritorial() {
    this.model.varActividad.push({ notacion_actividad_id: 0, actividad_id: 0, estados: 0, NuevoRegistro: true });
  }

  deleteTerritorial(index) {
    this.model.varActividad.splice(index, 1);
  }

  addObserv() {
    this.model.varObserv.push({ id: 1, NuevoRegistro: true });
  }

  deleteObserv(index) {
    this.model.varObserv.splice(index, 1);
  }

  addOrgan() {
    this.model.varOrgan.push({ id: 1, anotacion_id: 0, organizacion_id: 0, subestructura_id: 0, estructura_id: 0, grupo_id: 0, observacion: "", NuevoRegistro: true });
    this.GetListaEstructura(0, this.model.varOrgan.length - 1);
    this.GetListaGrupo(0, this.model.varOrgan.length - 1);
  }

  deleteOrgan(index) {
    this.model.varOrgan.splice(index, 1);
  }
  addOrgan2() {
    this.model.varOrgan2.push({ id: 1, anotacion_id: 0, organizacion_id: 0, subestructura_id: 0, estructura_id: 0, grupo_id: 0, observacion: "", NuevoRegistro: true });
  }

  deleteOrgan2(index) {
    this.model.varOrgan2.splice(index, 1);
  }

  addComp() {
    this.model.varComp.push({ anotacion_cobio_id: 0, anotacion_id: 0, organizacion_id: 0, num_identificacion: "", persona_id: 0, tipo_persona_id: 0, actividad_delictiva_id: 0, rol_id: 0, pralias_id: 0, nombreCompleto: "", observaciones: "", NuevoRegistro: true });
  }

  deleteComp(index) {
    this.model.varComp.splice(index, 1);
  }

  addComp2() {
    this.model.varComp2.push({ organizacion_id: 0, actividad_delictiva_id: 0, rol_id: 0, pralias_id: 0, observaciones: "", NuevoRegistro: true });
  }

  deleteComp2(index) {
    this.model.varComp2.splice(index, 1);
  }

  addCSenal() {
    this.model.varSenal.push({ tipo_id: 0, isExterno: false, NuevoRegistro: true });
  }

  deleteCSenal(index) {
    this.model.varSenal.splice(index, 1);
  }

  addCRasgo() {
    this.model.varRasgo.push({ id: 1, isExterno: false, NuevoRegistro: true });
  }

  deleteCRasgo(index) {
    this.model.varRasgo.splice(index, 1);
  }

  openSenal(datos: any, i: number) {
    if (this.model.tipoIdent) {
      this.model.varSenalInfo.id = datos.persona_id;
      this.model.varSenalInfo.nombres = datos.nombreCompleto;
      this.ObtenerSenialesYrasgos({ anotacion_id: this.model.anotacion_id, persona_id: Number(datos.persona_id) });
      this.ObtenerInfoEspecial({ anotacion_id: this.model.anotacion_id, persona_id: Number(datos.persona_id) });
    } else {
      this.model.varSenalInfo.id = Number(datos.pralias_id);
      this.model.varSenalInfo.nombres = this.model.lstAlias[i].filter(x => x.alias_id == Number(datos.pralias_id))[0].aliasnn;
      this.ObtenerSenialesYrasgos({ anotacion_id: this.model.anotacion_id, pralias_id: Number(datos.pralias_id) });
    }
    this.model.senalModal = true;
  }


  closeSenalModal(bol: any) {
    this.model.senalModal = bol;
  }

  addMovim() {
    this.model.varMovim.push({ id: 1, anotacion_id: 0, informe_migratorio: "", NuevoRegistro: true });
  }

  deleteMovim(index) {
    this.model.varMovim.splice(index, 1);
  }

  openMigratorioDetalle(item: any) {
    this.model.varMigratorioDetalle.informe_migratorio = item.informe_migratorio;
    let response = this.validaciones.ValidacionesStepSiete(this.model);
    if (!response.error) { 
      this.CrearAnotacionesStep6(item.NuevoRegistro==true ? [item]: []);
      this.ActualizarAnotacionesStep6(item.NuevoRegistro!=true ? [item]: []);
    }
    else {
      swal({
        text: response.error_msg,
        showConfirmButton: true,
        type: 'warning',
        confirmButtonText: 'Aceptar'
      });
    }
  }

  closeMigratorioModal(bol: any) {
    this.model.migratModal = bol;
  }

  addMigrat() {
    this.model.varMigrat.push({
      pais_origen_id: 0, pais_destino_id: 0, municipio_contacto_id: 0, nacionalidad_id: 0,
      tipo_documento_id: 0,
      num_identificacion: '',
      nombre_completo: '',
      ocupacion: '',
      num_contacto: '',
      correo_electronico: '',
      dias_estadia: '',
      NuevoRegistro: true
    });
  }

  deleteMigrat(index) {
    this.model.varMigrat.splice(index, 1);
  }
  addMigratPersona() {
    this.model.varMigratPersona.push({ tipo_documento_id: 0, NuevoRegistro: true });
  }

  deleteMigratPersona(index) {
    this.model.varMigratPersona.splice(index, 1);
  }

  openVinc() {
    this.model.vincModal = true;
  }

  closeVincModal(bol: any) {
    this.model.vincModal = bol;
  }

  OpenInfoPersonas(item: any, index: number) {
    this.model.migratPersonalModal = true;
    this.model.varMigratPersona[0] = item;
    this.model.varMigratPersona[0].index = index;
  }

  GuardarInfoPersonas(item: any) {
    this.model.varMigrat[item.index] = item;
    this.model.migratPersonalModal = false;
  }

  changePropietario() {
    $(".depends").hide();
    if (this.model.varDetalle.propietario_id != 0 && this.model.varDetalle.propietario_id != undefined) {
      this.model.varDetalle.codigo = this.model.listPropietario.filter(x => x.id == this.model.varDetalle.propietario_id)[0].codigo;
      if (this.model.varDetalle.codigo != undefined && this.model.varDetalle.codigo != 0)
      this.model.varDetalle.unidad_id=0;
      this.model.varDetalle.unidad = '';
      this.model.varDetalle.dependencia_id =0;
      this.model.varDetalle.dependencia = '';
      this.model.varDetalle.funcionario_id = 0;
      this.model.varDetalle.funcionario = '';
      this.model.varDetalle.grado = '';
        $(".depends" + this.model.varDetalle.codigo).show();
    }
  }
  
  addBDetalle() {
    this.model.varBDetalle.push({ atributo_id: 0, detalle: "", NuevoRegistro: true });
  }

  deleteBDetalle(index) {
    this.model.varBDetalle.splice(index, 1);
  }


  // Cobios
  gotoprofile(step: any) {
    this.model.profilestep = step;
  }

  openComponente() {
    this.model.componenteModal = true;
  }

  closeComponenteModal(bol: any) {
    this.model.componenteModal = bol;
  }

  openCobios(nperfil: any) {
    this.model.cobiosModal = true;
    this.model.perfil = nperfil;
    this.model.profilestep = 1;
    this.model.fotoPerfil = "../../../../assets/images/avatar.jpg";
    this.model.fotoNoPerfil = "../../../../assets/images/avatar.jpg";
  }

  closeCobiosModal(bol: any) {
    this.model.cobiosModal = bol;
  }

  closeDetalleModal(bol: any) {
    this.model.detalleModal = bol;
  }

  addActividad() {
    this.model.varActividad.push({ id: 1, actividad: "", NuevoRegistro: true });
  }

  deleteActividad(index) {
    this.model.varActividad.splice(index, 1)
  }

  addNacionalidad() {
    this.model.varNacionalidades.push({ id: 1, NuevoRegistro: true });
  }

  deleteNacionalidad(index) {
    this.model.varNacionalidades.splice(index, 1);
  }

  addContacto() {
    this.model.varContactos.push({ id: 1, NuevoRegistro: true });
  }

  deleteContacto(index) {
    this.model.varContactos.splice(index, 1);
  }

  addFamiliar() {
    this.model.varFamiliar.push({ id: 1, NuevoRegistro: true });
  }

  deleteFamiliar(index) {
    this.model.varFamiliar.splice(index, 1);
  }

  addSenal() {
    this.model.varSenales.push({ id: 1, NuevoRegistro: true });
  }

  deleteSenal(index) {
    this.model.varSenales.splice(index, 1);
  }

  addEspecial() {
    this.model.varEspecial.push({ id: 1, NuevoRegistro: true });
  }

  deleteEspecial(index) {
    this.model.varEspecial.splice(index, 1);
  }

  openIdentidad() {
    this.model.identidadModal = true;
  }

  closeIdentidadModal(bol: any) {
    this.model.identidadModal = bol;
  }

  openVincular() {
    this.model.vincularModal = true;
  }

  closeVincularModal(bol: any) {
    this.model.vincularModal = bol;
  }

  openTipificacion() {
    this.model.tipificacionModal = true;
  }

  closeTipificacionModal(bol: any) {
    this.model.tipificacionModal = bol;
  }

  openAlias() {
    this.model.aliasModal = true;
  }

  closeAliasModal(bol: any) {
    this.model.aliasModal = bol;
  }

  addFormacion() {
    this.model.varFormacion.push({ id: 1, NuevoRegistro: true });
  }

  deleteFormacion(index) {
    this.model.varFormacion.splice(index, 1);
  }

  addIdioma() {
    this.model.varIdioma.push({ id: 1, NuevoRegistro: true });
  }

  deleteIdioma(index) {
    this.model.varIdioma.splice(index, 1);
  }

  addLaboral() {
    this.model.varLaboral.push({ id: 1, NuevoRegistro: true });
  }

  deleteLaboral(index) {
    this.model.varLaboral.splice(index, 1);
  }

  save() {
    this.model.modal = false;
  }

  changeProfile(files) {
    if (files.length == 0) return;

    var mimeType = files[0].type;
    if (mimeType.match(/image\/*/) == null) {
      swal({
        title: 'ERROR',
        text: 'Por favor seleccione una imagen (jpeg o png)',
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'error',
      });
      return;
    }
    var reader = new FileReader();
    reader.readAsDataURL(files[0]);
    reader.onload = (_event) => {
      this.model.fotoPerfil = reader.result;
    }
  }

  changeNoProfile(files) {
    if (files.length == 0) return;

    var mimeType = files[0].type;
    if (mimeType.match(/image\/*/) == null) {
      swal({
        title: 'ERROR',
        text: 'Por favor seleccione una imagen (jpeg o png)',
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'error',
      });
      return;
    }
    var reader = new FileReader();
    reader.readAsDataURL(files[0]);
    reader.onload = (_event) => {
      this.model.fotoNoPerfil = reader.result;
    }
  }

  // Corgas
  gotoprofile1(step: any) {
    this.model.profilestep1 = step;
  }

  closeCorgasModal(bol: any) {
    this.model.corgasModal = bol;
  }

  openRecoleccion() {
    this.model.recoleccionModal = true;
    this.model.varRecoleccion1 = [];
  }

  closeRecoleccionModal(bol: any) {
    this.model.recoleccionModal = bol;
  }

  openReporte() {
    this.model.reporteModal = true;
    // this.model.Rango_fechas = "";
    // setTimeout(() => {
    //   let th = this;
    //   this.model.calendar = $('.datepicker-range').datepicker({
    //     clearButton: true,
    //     onSelect: function (data) {
    //       th.Rango_fechas = data;
    //     }
    //   }).data('datepicker');
    // }, 300);
    // this.model.calendar.clear();
  }

  closeReporteModal(bol: any) {
    this.model.reporteModal = bol;
  }

  openCDetalle() {
    this.model.detalle1Modal = true;
  }

  closeCDetalleModal(bol: any) {
    this.model.detalle1Modal = bol;
  }

  addResena() {
    this.model.varResena.push({ id: 1, NuevoRegistro: true })
  }

  deleteResena(index) {
    this.model.varResena.splice(index, 1);
  }

  changeTabs(ntab: any) {
    this.model.tab = ntab;
  }

  changeProfile1(files) {
    if (files.length == 0) return;

    var mimeType = files[0].type;
    if (mimeType.match(/image\/*/) == null) {
      swal({
        title: 'ERROR',
        text: 'Por favor seleccione una imagen (jpeg o png)',
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'error',
      });
      return;
    }
    var reader = new FileReader();
    reader.readAsDataURL(files[0]);
    reader.onload = (_event) => {
      this.model.foto = reader.result;
    }
  }

  changeLogo(files) {
    if (files.length == 0) return;

    var mimeType = files[0].type;
    if (mimeType.match(/image\/*/) == null) {
      swal({
        title: 'ERROR',
        text: 'Por favor seleccione una imagen (jpeg o png)',
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'error',
      });
      return;
    }
    var reader = new FileReader();
    reader.readAsDataURL(files[0]);
    reader.onload = (_event) => {
      this.model.logo = reader.result;
    }
  }

  NotificarAprobacion() {
    this.model.varAnotaciones.estado_id = JSON.parse(localStorage.getItem(CONST_LISTADINAMICA)).find(x => x.nombre == CONST_AD_ESTADOS).detalle.filter(x => x.detalleCorto == CONST_POR_APROBAR)[0].id;
    this.model.varAnotaciones.mision_trabajo_id = Number(this.model.varAnotaciones.mision_trabajo_id);
    this.model.varAnotaciones.categoria_id = Number(this.model.varAnotaciones.categoria_id);
    this.api.ActualizarAnotaciones(this.model.varAnotaciones).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.anotacion_id = Number(response.id);

        swal({
          text: 'La solicitud ha sido enviada con exito',
          allowOutsideClick: false,
          showConfirmButton: true,
          type: 'success',
        }).then(result => {
          this.filter(this.model.pagActual, this.model.inputSearch);
          this.model.modal = false;
        });
      }
    });
  }

  openBitacora() {
    this.model.bitacoraModal = true;
  }

  closeBitacoraModal(bol: any) {
    this.model.bitacoraModal = false;
  }

  /** Guarda Auditoria de los Search */
  BlurSearch() {
    let respuesta = "";
    this.model.varhistorial.forEach(x => respuesta += (respuesta != "" ? (',' + x.anotacion_id) : x.anotacion_id));
    let Json = {
      Url_pantalla: "Anotaciones",
      Texto_consulta: this.model.inputSearch,
      Resultados_grilla: respuesta,
      Ip_equipo: '192.168.2.255',
      Maquina: 'prueba scano/spinilla'
    };
    this.api.CrearAuditoriaGrilla(Json).subscribe();
  }


  /** PAGINADOR */
  next() {
    this.filter(((this.model.pagActual += 1) * 200), this.model.inputSearch);
  }
  prev() {
    this.filter(((this.model.pagActual -= 1) * 200), this.model.inputSearch);
  }

  //Remplazar para los who columns y la info necesaria
  items = {
    AUsuarioCreador: "",
    BFechaCreacion: "",
    CUsuarioModificador: "",
    DFechaModificacion: "",
    ETabla: ""
  };

  who: boolean;

  openTools() {
    this.model.tools = !this.model.tools;
  }

  closeTools() {
    this.model.tools = false;
  }

  closeWho(bol: boolean) {
    this.model.who = bol;
  }

  closeModalSelect(bol: any, type: number) {
    if (type == 1) this.model.selectmodal = bol;
    else if (type == 2) this.model.select1modal = bol;
  }

  openInforow(data: any) {
    this.who = true;
    let jsonreporte = {
      "id": data.evaluacionId
    };

    this.api.GetEvaluacionFuncionariosInd(jsonreporte).subscribe(data => {
      setTimeout(() => { this.model.loadingitem = false; }, 1000);
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.items.AUsuarioCreador = response.result[0].usuarioCreador;
        this.items.BFechaCreacion = response.result[0].fechaCreacion;
        this.items.CUsuarioModificador = response.result[0].usuarioModificador;
        this.items.DFechaModificacion = response.result[0].fechaModificacion;
        this.items.ETabla = response.result[0].tabla;
      }

    });
  }


  GetAnotacionesCorgas(anotacion_id: any) {
    this.api.GetAnotacionesCorgas({ id: Number(anotacion_id) }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        console.log(response.result);
        this.model.varOrgan = response.result.filter(x => x.organizacion_id == 0);;
        this.model.varOrgan2 = response.result.filter(x => x.organizacion_id != 0);
      }
    });
  }

  GetAnotacionesCobios(anotacion_id: any) {
    this.api.GetAnotacionesCobios({ id: Number(anotacion_id) }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varComp = response.result.filter(x => x.persona_id != 0);
        this.model.varComp2 = response.result.filter(x => x.pralias_id != 0);
        this.model.varComp.forEach(x => {
          this.ObtenerDatosPersona(x);
        });
        for (let index = 0; index < this.model.varComp2.length; index++) {
          const element = this.model.varComp2[index];
          this.changeOrganizacionDos(element, index, true)
        }
      }
    });
  }

  public GetListaInOrganizaciones() {
    this.api.GetAnotacionesInOrganizaciones({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listOrganizaciones = response.result;
      }
    })
  }

  public GetListaSubestructura() {
    this.api.GetAnotacionesSubestructuras({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listsubestructura = response.result;
        this.model.listsubestructuraDet = response.result;
      }
    })
  }

  /** Obtiene a lista de estructuras */
  public GetListaEstructura(subestructuraid: Number, index: number) {
    this.api.GetAnotacionesEstructuras({ id: subestructuraid }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listestructura[index] = response.result;
        if (response.result.length == 1) {
          this.model.inputfrom = "unidad-destino-estructura";
          this.datafrom(response.result[0], 1);
        }
      }
    })
  }

  /** Obtiene a lista de grupos */
  public GetListaGrupo(estructuraid: Number, index: number) {
    this.api.GetAnotacionesGrupos({ id: estructuraid }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listgrupo[index] = response.result;

        if (response.result.length == 1) {
          this.model.inputfrom = "unidad-destino-grupo";
          this.datafrom(response.result[0], 1);
        }
      }
    })
  }

  changeactividad(data: any, IsCargue: boolean) {
    if (data.actividad_id != 0) {
      data.requiere_fechas = this.model.ListaActividades.filter(x => x.actividad_id == Number(data.actividad_id))[0].requiere_fechas;
      data.requiere_estados = this.model.ListaActividades.filter(x => x.actividad_id == Number(data.actividad_id))[0].requiere_estados;
    }
    if (!IsCargue || data.actividad_id == 0) {
      delete data.fecha_inicio;
      delete data.fecha_fin;
      data.estados = 0;
    }
  }

  changeEstructura(data: any, index: number) {
    this.GetListaGrupo(Number(data.estructura_id), index);
  }

  changeOrganizacion(item: any, index: number) {
    this.api.GetAnotacionesAliasXOrganizacion({ "id": Number(item.organizacion_id) }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.lstAlias[index] = response.result;
        item.pralias_id = 0;
      }
    });
  }

  changeOrganizacionDos(item: any, index: number, IsCargue: boolean) {
    this.api.GetAnotacionesAliasXOrganizacion({ "id": Number(item.organizacion_id) }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.lstAlias[index] = response.result;
        if (!IsCargue)
          item.pralias_id = 0;
      }
    });
  }

  changeOrganizacionTres(IsCargue: boolean) {
    if (this.model.varDetalle.organizacion_id != undefined && this.model.varDetalle.organizacion_id != 0)
      this.api.GetAnotacionesAliasXOrganizacion({ "id": Number(this.model.varDetalle.organizacion_id) }).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.lstAliasDet = response.result;
          if (!IsCargue)
            this.model.varDetalle.alias_id = 0;
        }
      });
  }

  changeOrganizacionDet(item: any) {
    this.api.GetAnotacionesAliasXOrganizacion({ "id": Number(item.organizacion_id) }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.lstAliasDet = response.result;
      }
    });
  }

  // changeGrupDet(data: any) {
  //   this.api.GetAnotacionesAliasXOrganizacion({ "id": Number(data.grupo_id) }).subscribe(data => {
  //     let response: any = this.api.ProcesarRespuesta(data);
  //     if (response.tipo == 0) {
  //       this.model.lstAliasDet = response.result;
  //     }
  //   });
  // }

  GetListaInOrganizacionesIlegales() {
    this.api.GetAnotacionesInOrganizacionesIlegales({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listOrganizacionesIlegales = response.result;
      }
    })
  }

  public ObtenerDatosPersona(persona: any) {
    let num_identificacion: any = persona.num_identificacion;
    if (num_identificacion != "" && num_identificacion != null && num_identificacion != undefined) {
      persona.buscandoSearch = true;
      this.api.ObtenerDatosEvaluadoComite({ "id": Number(num_identificacion) }).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        persona.buscandoSearch = false;
        if (response.tipo == 0 && response.result.personaId != 0) {
          persona.persona_id = Number(response.result.personaId);
          persona.nombreCompleto = response.result.grado + '. ' + response.result.apellido + ' ' + response.result.nombre;
        } else {
          swal({
            title: 'ERROR',
            text: 'El componente biografico no existe, porfavor crear el componente.',
            allowOutsideClick: false,
            showConfirmButton: true,
            type: 'error',
          });
        }
      });
    }
  }

  private ObtenerBienesElementos() {
    this.api.GetAnotacionesBienesElementos({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listTipoBienHist = response.result;
        this.model.listTipoBienHistDet = response.result;
        this.model.listTipoBien = [];
        this.model.listTipoBienDet = [];
        [...new Set(response.result.map(x => x.tipo))].forEach(x => this.model.listTipoBien.push({ id: x, detalle: x }));
        [...new Set(response.result.map(x => x.tipo))].forEach(x => this.model.listTipoBienDet.push({ id: x, detalle: x }));
      }
    })
  }

  changeTipoBien() {
    this.model.listClase = [{ id: '', nombre: 'Seleccionar' }];
    this.model.listMarca = [{ id: '', nombre: 'Seleccionar' }];
    [...new Set(this.model.listTipoBienHist.filter(y => y.tipo == this.model.varBusquedaDetalle.tipo_bien).map(x => x.clase))].forEach(x => this.model.listClase.push({ id: x, nombre: x }));
    delete this.model.varBusquedaDetalle.clase;
    delete this.model.varBusquedaDetalle.marca;
    this.model.varDetalle.propietario_id = 0;
    this.model.varDetalle.detalle = '';
  }

  changeTipoBienDet(IsCargue: boolean) {
    this.model.listClaseDet = [{ id: '', nombre: 'Seleccionar' }];
    this.model.listMarcaDet = [{ id: '', nombre: 'Seleccionar' }];
    if(!IsCargue){
      delete this.model.varDetalle.clase;
      delete this.model.varDetalle.marca;
    }
    [...new Set(this.model.listTipoBienHistDet.filter(y => y.tipo == this.model.varDetalle.tipo_bien).map(x => x.clase))].forEach(x => this.model.listClaseDet.push({ id: x, nombre: x }));
  }

  changeClaseBien() {
    this.model.listMarca = [{ id: '', nombre: 'Seleccionar' }];
    [...new Set(this.model.listTipoBienHist.filter(y => y.clase == this.model.varBusquedaDetalle.clase).map(x => x.marca))].forEach(x => this.model.listMarca.push({ id: x, nombre: x }));
    delete this.model.varBusquedaDetalle.marca;
  }

  changeClaseBienDet(IsCargue: boolean) {
    this.model.listMarcaDet = [{ id: '', nombre: 'Seleccionar' }];
    if(!IsCargue)
      delete this.model.varDetalle.marca;
    [...new Set(this.model.listTipoBienHistDet.filter(y => y.clase == this.model.varDetalle.clase).map(x => x.marca))].forEach(x => this.model.listMarcaDet.push({ id: x, nombre: x }));
  }
  
  changeMarcaBienDet() {
    let data:any  = this.model.listTipoBienHistDet.filter(y => y.clase == this.model.varDetalle.clase && y.marca ==this.model.varDetalle.marca);
    if(data.length > 0)
      this.model.varDetalle.bien_elemento_id = Number(data[0].bien_elemento_id);
    else
      this.model.varDetalle.bien_elemento_id = 0;
    this.obtenerAtributos(this.model.varDetalle.bien_elemento_id);
  }

  private obtenerAtributos(bien_elemento_id: any) {
    this.model.listAtributos = [];
    if (bien_elemento_id != 0)
      this.api.ObtenerBienesElementosAnotaciones({ id: bien_elemento_id }).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.listAtributos = response.result;

        }
      });
  }



  buscarBienes() {
    let datos: any = {
      tipo_bien: this.model.varBusquedaDetalle.tipo_bien == '0' ? "" : this.model.varBusquedaDetalle.tipo_bien,
      clase: this.model.varBusquedaDetalle.clase == undefined ? "" : this.model.varBusquedaDetalle.clase,
      marca: this.model.varBusquedaDetalle.marca == undefined ? "" : this.model.varBusquedaDetalle.marca,
      detalle: this.model.varBusquedaDetalle.detalle,
      propietario: this.model.varBusquedaDetalle.propietario_id == '0' ? "" : this.model.listPropietario.filter(x => x.id == Number(this.model.varBusquedaDetalle.propietario_id))[0].detalle,
      anotacion_id: this.model.anotacion_id
    };
    this.api.GetAnotacionesFiltrosBienes(datos).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varResultBien = response.result;
        this.model.NBienesRelacionados = this.model.varResultBien.filter(det=> det.padre_id==this.model.varAnotaciones.anotacion_id && det.origen=='A').length;
      }
    });
  }

  openBienRelacion(item: any, IslecturaDetalle: boolean) {
    this.cleanDetalleUnidad();
    this.model.IslecturaDetalle = IslecturaDetalle;
    this.model.varDetalle.anotacion_bien_id = item.registro_id;
    this.model.bienModal = true;
    this.model.varDetalle = item;

    this.model.vtipoIdent='I';
    if(this.model.varDetalle.organizacion_id != 0 && this.model.varDetalle.organizacion_id!=undefined && this.model.varDetalle.alias_id==0){
      this.model.vtipoIdent='O';
    }else if(this.model.varDetalle.alias_id!=0 && this.model.varDetalle.alias_id!=undefined){
      this.model.vtipoIdent='A';
    }
    
    this.changeTipoBienDet(true);
    this.changeClaseBienDet(true);
    this.changeOrganizacionTres(true)
    this.api.GetAnotacionesBienesDetalleId({ id: item.registro_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varBDetalle = response.result;
        this.obtenerAtributos(this.model.varDetalle.bien_elemento_id);

      }
    });
  }

  openDetalleRelaciones() {
    this.model.bienModal = true;
    this.cleanDetalleUnidad();
  }

  cleanDetalleUnidad() {
    this.model.varDetalle = new Model().varDetalle;
    this.model.listClase = [];
    this.model.listMarca = [];
    this.model.varBDetalle = [];
    this.model.lstAliasDet = [];
    this.model.IslecturaDetalle = false;
    setTimeout(() => {
      this.changePropietario();
    }, 50);
  }

  changeDetalleBien() {
    this.model.detalleUnidad = !this.model.detalleUnidad;
    this.model.varDetalle = new Model().varDetalle;
    this.model.listClaseDet = [];
    this.model.listMarcaDet = [];
    this.changePropietario();
    this.model.varBDetalle = [];
  }

  changeMultimedia(files: FileList, modelo: any) {

    if (files.length == 0) {
      swal({
        title: 'ERROR',
        text: 'Por favor seleccione un archivo',
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'error',
      });
      return;
    }
    var reader = new FileReader();
    reader.readAsDataURL(files[0]);
    reader.onload = (_event) => {
      this.model.varDetalle.multimedia = files[0];
      this.model.varDetalle.nombreMultimedia = ' ...' + files[0].name.substring(0, 10);
    }
  }

  CrearRelacionar(requestRelacionar: any) {
    if (requestRelacionar != null) {

      let formData = new FormData();
      formData.append('files', requestRelacionar.multimedia);
      formData.append('model', JSON.stringify(requestRelacionar));

      this.api.CrearAnotacionesBienes(formData).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.varDetalle.NuevoRegistro = false;
          this.model.varDetalle.anotacion_bien_id = Number(response.id);
          this.CrearRelacionarDetalle(this.model.varBDetalle.filter(x => x.NuevoRegistro == true));
          swal({
            text: response.mensaje,
            showConfirmButton: true,
            type: 'success',
            confirmButtonText: 'Aceptar'
          }).then(x => {
            this.model.bienModal = false;
            this.buscarBienes();
          });
        }
      })
    }
  }

  ActualizarRelacionar(requestRelacionar: any) {
    if (requestRelacionar != null) {

      let formData = new FormData();
      formData.append('files', requestRelacionar.multimedia);
      formData.append('model', JSON.stringify(requestRelacionar));

      this.api.ActualizarAnotacionesBienes(formData).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.varDetalle.NuevoRegistro = false;
          this.model.varDetalle.anotacion_bien_id = Number(response.id);
          this.CrearRelacionarDetalle(this.model.varBDetalle.filter(x => x.NuevoRegistro == true));
          this.ActualizarRelacionarDetalle(this.model.varBDetalle.filter(x => x.NuevoRegistro != true));
          swal({
            text: response.mensaje,
            showConfirmButton: true,
            type: 'success',
            confirmButtonText: 'Aceptar'
          }).then(x => {
            this.model.bienModal = false;
            this.buscarBienes();
          });
        }
      })
    }
  }

  /**
   * Metodo encargado de asociar la relación
   * @param requestRelacionarDet Lista de detalles 
   */
  CrearRelacionarDetalle(requestRelacionarDet: any) {
    if (requestRelacionarDet.length > 0) {
      requestRelacionarDet.forEach(x => {
        x.atributo_id = Number(x.atributo_id);
        x.anotacion_bien_id = Number(this.model.varDetalle.anotacion_bien_id);
      });
      this.api.CrearAnotacionesBienesDetalle(requestRelacionarDet).subscribe(data => {
        this.api.ProcesarRespuesta(data);
      })
    }
  }

  /**
   * Metodo encargado de asociar la relación
   * @param requestRelacionarDet Lista de detalles 
   */
  ActualizarRelacionarDetalle(requestRelacionarDet: any) {
    if (requestRelacionarDet.length > 0) {
      requestRelacionarDet.forEach(x => {
        x.atributo_id = Number(x.atributo_id);
        x.anotacion_bien_id = Number(this.model.varDetalle.anotacion_bien_id);
      });
      this.api.ActualizarAnotacionesBienesDetalle(requestRelacionarDet).subscribe(data => {
        this.api.ProcesarRespuesta(data);
      })
    }
  }

  GuardarDetalleRelacion() {
    this.model.varDetalle.anotacion_id = this.model.anotacion_id;
    this.model.varDetalle.propietario_id = Number(this.model.varDetalle.propietario_id);
    this.model.varDetalle.alias_id = Number(this.model.varDetalle.alias_id);
    this.model.varDetalle.organizacion_id = Number(this.model.varDetalle.organizacion_id);

    let response = this.validaciones.ValidacionesDetallesRelacionados(this.model);
    if (!response.error) {
      this.CrearRelacionar(this.model.varDetalle.NuevoRegistro == true ? this.model.varDetalle : null);
      this.ActualizarRelacionar(this.model.varDetalle.NuevoRegistro != true ? this.model.varDetalle : null);
    }
    else {
      swal({
        text: response.error_msg,
        showConfirmButton: true,
        type: 'warning',
        confirmButtonText: 'Aceptar'
      });
    }
  }

  GetAnotacionesMigratorios(anotacion_id: any) {
    this.api.GetAnotacionesMigratorios({ id: Number(anotacion_id) }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        response.result.forEach(element => {
          element.fecha_inicio = this.Utilidades.parseDate(element.fecha_inicio, false);
          if (element.fecha_termino != "0001-01-01T00:00:00") {
            element.fecha_termino = this.Utilidades.parseDate(element.fecha_termino, false);
          } else {  delete element.fecha_termino; }
        });
        this.model.varMovim = response.result;
      }
    })
  }

  GetAnotacionesMigratoriosDetalle(anotacion_migratorio_id: any) {
    this.api.GetAnotacionesMigratoriosDet({ id: anotacion_migratorio_id }).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varMigrat = response.result;
      }
    })
  }

  GetAnotacionesMunicipios() {
    this.api.GetAnotacionesMunicipios({}).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.listMunicipios = response.result;
      }
    })
  }

  CrearMigratorioDet(requestMigratDet: any) {
    if (requestMigratDet.length > 0) {
      this.api.CrearAnotacionesMigratoriosDet(requestMigratDet).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.migratModal = false;
          this.model.varMigrat = [];

        }
      })
    }
  }

  ActualizarMigratorioDet(requestMigratDet: any) {
    if (requestMigratDet.length > 0) {
      this.api.ActualizarAnotacionesMigratoriosDet(requestMigratDet).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        if (response.tipo == 0) {
          this.model.migratModal = false;
          this.model.varMigrat = [];

        }
      })
    }
  }

  GuardarMigratorioDet() {
    this.model.varMigrat.forEach(element => {
      element.anotacion_migratorio_id = this.model.varMigratorioDetalle.anotacion_migratorio_id;
      element.pais_origen_id = Number(element.pais_origen_id);
      element.pais_destino_id = Number(element.pais_destino_id);
      element.nacionalidad_id = Number(element.nacionalidad_id);
      element.tipo_documento_id = Number(element.tipo_documento_id);
      element.num_contacto = Number(element.num_contacto);
    });
    this.CrearMigratorioDet(this.model.varMigrat.filter(x => x.NuevoRegistro == true));
    this.ActualizarMigratorioDet(this.model.varMigrat.filter(x => x.NuevoRegistro != true));

  }

  openVincularAlias(det) {
    this.model.pralias_id = det.pralias_id;
    this.model.vincularModal = true;
    this.clearVinculacionAlias();
  }

  clearVinculacionAlias() {
    this.model.vincularAlias = new Model().vincularAlias;
  }

  public ObtenerDatosPersonaAnotaciones() {
    if ((this.model.vincularAlias.id != "" && this.model.vincularAlias.id != null && this.model.vincularAlias.id != undefined)
      && (this.model.vincularAlias.dataText != "0")) {
      this.api.GetAnotacionesPersonas(this.model.vincularAlias).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        this.model.vincularAlias.IsReady = false;
        if (response.tipo == 0 && response.result.length > 0) {
          this.model.vincularAlias.persona_id = response.result[0].id;
          this.model.vincularAlias.nombres = response.result[0].primerNombre;
          this.model.vincularAlias.apellidos = response.result[0].primerApellido;
          this.model.vincularAlias.fotografia = response.result[0].fotografia;
          this.model.vincularAlias.IsReady = true;
        }
        else {
          swal({
            title: 'Error',
            text: 'Identificación no encontrada.',
            allowOutsideClick: false,
            showConfirmButton: true,
            type: 'warning',
          });
        }
      });
    } else {
      swal({
        title: 'Error',
        text: 'Falta Tipo Documento o N° Documento por informar',
        allowOutsideClick: false,
        showConfirmButton: true,
        type: 'warning',
      });
    }
  }

  CrearVinculacionAlias() {
    this.model.vincularAlias.alias_id = Number(this.model.pralias_id);
    this.api.CrearAnotacionesVincularAlias(this.model.vincularAlias).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        swal({
          text: response.mensaje,
          showConfirmButton: true,
          type: 'success',
          confirmButtonText: 'Aceptar'
        }).then(x => {
          this.model.vincularModal = false;
        });
      }
    });
  }

  public ObtenerDatosPersonaDet() {
    let num_identificacion: any = this.model.varDetalle.num_identificacion;
    if (num_identificacion != "" && num_identificacion != null && num_identificacion != undefined) {
      this.model.varDetalle.buscandoSearch = true;
      this.api.ObtenerDatosEvaluadoComite({ "id": Number(num_identificacion) }).subscribe(data => {
        let response: any = this.api.ProcesarRespuesta(data);
        this.model.varDetalle.buscandoSearch = false;
        if (response.tipo == 0 && response.result.personaId != 0) {
          this.model.varDetalle.nombre = response.result.grado + '. ' + response.result.apellido + ' ' + response.result.nombre;
          this.model.varDetalle.persona_id = Number(response.result.personaId);
        } else {
          swal({
            title: 'ERROR',
            text: 'El componente biografico no existe, porfavor crear el componente.',
            allowOutsideClick: false,
            showConfirmButton: true,
            type: 'error',
          }).then(res=>
            {
              this.model.varDetalle.nombre = '';
            });
        }
      });
    }
  }

  /**
  * Amplia el tamaño de una Caja de texto
  * @param dato Dato donde se guardara la informacion
  */
 AmpliarTextoDescripcion(dato: any) {
  swal({
    title: 'Descripción',
    input: 'textarea',
    showCancelButton: false,
    animation: "slide-from-top",
    showConfirmButton: true,
    width: 1200,
    onBeforeOpen: ((result) => {
      $(".swal2-textarea").val(dato.descripcion);
      $(".swal2-textarea").css("resize", "none");
      $(".swal2-textarea").css("height", "600px");
      $(".swal2-textarea").prop("disabled", true);
    }),
  });
}

  /**
  * Amplia el tamaño de una Caja de texto
  * @param dato Dato donde se guardara la informacion
  */
  AmpliarTextoObservacion(dato: any, Islectura: boolean) {
    swal({
      title: 'Observación especifica',
      input: 'textarea',
      showCancelButton: false,
      animation: "slide-from-top",
      showConfirmButton: true,
      width: 800,
      onBeforeOpen: ((result) => {
        $(".swal2-textarea").val(dato.observacion);
        $(".swal2-textarea").css("resize", "none");
        $(".swal2-textarea").prop("disabled", Islectura);
      }),
    }).then((result) => {
      if (result.value != undefined)
        dato.observacion = result.value;
    });
  }

  guardarSenales() {
    this.CrearRasgosMorfologicos(this.model.varRasgo.filter(x => x.NuevoRegistro == true && !x.isExterno));
    this.ActualizarRasgosMorfologicos(this.model.varRasgo.filter(x => x.NuevoRegistro != true && !x.isExterno));

    this.CrearSeniales(this.model.varSenal.filter(x => x.NuevoRegistro == true && !x.isExterno));
    this.ActualizarSeniales(this.model.varSenal.filter(x => x.NuevoRegistro != true && !x.isExterno));
    if (this.model.tipoIdent)
      this.GuardarIdentificacionEspecial();
  }

  private CrearRasgosMorfologicos(requestRasgosMorfologicos: any) {
    if (requestRasgosMorfologicos.length > 0) {
      requestRasgosMorfologicos.forEach(x => {
        x.Anotacion_id = this.model.anotacion_id;
        if (this.model.tipoIdent) x.persona_id = this.model.varSenalInfo.id;
        if (!this.model.tipoIdent) x.Pralias_id = this.model.varSenalInfo.id;
      });
      this.api.CrearAnotacionesRasgos(requestRasgosMorfologicos).subscribe(data => {
        this.api.ProcesarRespuesta(data);
        this.model.senalModal = false;
      });
    }
  }

  private ActualizarRasgosMorfologicos(requestRasgosMorfologicos: any) {
    if (requestRasgosMorfologicos.length > 0) {
      requestRasgosMorfologicos.forEach(x => {
        x.Anotacion_id = this.model.anotacion_id;
        if (this.model.tipoIdent) x.persona_id = this.model.varSenalInfo.id;
        if (!this.model.tipoIdent) x.Pralias_id = this.model.varSenalInfo.id;
      });
      this.api.ActualizarAnotacionesRasgos(requestRasgosMorfologicos).subscribe(data => {
        this.api.ProcesarRespuesta(data);
        this.model.senalModal = false;
      });
    }
  }

  private CrearSeniales(requestSeniales: any) {
    if (requestSeniales.length > 0) {
      requestSeniales.forEach(x => {
        x.Anotacion_id = this.model.anotacion_id;
        if (this.model.tipoIdent) x.persona_id = this.model.varSenalInfo.id;
        if (!this.model.tipoIdent) x.Pralias_id = this.model.varSenalInfo.id;
        x.tipo_id = Number(x.tipo_id);
      });
      this.api.CrearAnotacionesSeniales(requestSeniales).subscribe(data => {
        this.api.ProcesarRespuesta(data);
        this.model.senalModal = false;
      });
    }
  }

  private ActualizarSeniales(requestSeniales: any) {
    if (requestSeniales.length > 0) {
      requestSeniales.forEach(x => {
        x.Anotacion_id = this.model.anotacion_id;
        if (this.model.tipoIdent) x.persona_id = this.model.varSenalInfo.id;
        if (!this.model.tipoIdent) x.Pralias_id = this.model.varSenalInfo.id;
        x.tipo_id = Number(x.tipo_id);
      });
      this.api.ActualizarAnotacionesSeniales(requestSeniales).subscribe(data => {
        this.api.ProcesarRespuesta(data);
        this.model.senalModal = false;
      });
    }
  }
  private GuardarIdentificacionEspecial() {
    this.model.varInfoEspeciales.Anotacion_id = this.model.anotacion_id;
    this.model.varInfoEspeciales.persona_id = this.model.varSenalInfo.id;
    this.model.varInfoEspeciales.tipo_desmovilizacion_id = Number(this.model.varInfoEspeciales.tipo_desmovilizacion_id);

    this.api.GuardarAnotacionesInfoEspeciales(this.model.varInfoEspeciales).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varInfoEspeciales.anotacion_infoespecial_id = response.id;
        this.model.senalModal = false;
      }
    });
  }

  ObtenerSenialesYrasgos(Json: any) {
    this.api.GetAnotacionesRasgosId(Json).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varRasgo = response.result;
      }
    });
    this.api.GetAnotacionesSenialesId(Json).subscribe(data => {
      let response: any = this.api.ProcesarRespuesta(data);
      if (response.tipo == 0) {
        this.model.varSenal = response.result;
      }
    });
  }

  changeVinculoIdentificado(valor: string)
  {
    this.model.vtipoIdent = valor;
    if(valor=='I')
    {
      this.model.varDetalle.organizacion_id=0;
      this.model.varDetalle.alias_id=0;
    }else if(valor=='A')
    {
      this.model.varDetalle.num_identificacion='';
      this.model.varDetalle.persona_id=0;
      this.model.varDetalle.nombre='';
    }else if(valor=='O')
    {
      this.model.varDetalle.num_identificacion='';
      this.model.varDetalle.persona_id=0;
      this.model.varDetalle.nombre='';
      this.model.varDetalle.alias_id=0;
    }
  }

  ObtenerInfoEspecial(Json: any) {
    this.model.varInfoEspeciales = new Model().varInfoEspeciales;
    this.api.GetAnotacionesInfoEspecialesId(Json).subscribe(data => {
       let response: any = this.api.ProcesarRespuesta(data);
       if(response.tipo==0 && response.result.length > 0 )
       {
          response.result.forEach(x=> {
            if(x.fecha != '0001-01-01T00:00:00')
              x.fecha = x.fecha.split('T')[0];
            else
              delete x.fecha
          });
          this.model.varInfoEspeciales = response.result[0];
       }
     });
 }

 obtenerNumMostrar()
 { 
  this.model.steps[1].ver =this.model.varAnotaciones.activarTerritorio;
  this.model.steps[2].ver =this.model.varAnotaciones.activarOrganico;
  this.model.steps[3].ver =this.model.varAnotaciones.activarBiografico;
  this.model.steps[4].ver =this.model.varAnotaciones.activarBienes;
  this.model.steps[5].ver =this.model.varAnotaciones.activarMovMigratorios;

  let aux = 1;
   this.model.steps.filter(x=> {
    x.numMostrar = 0;
    if(x.ver){
      x.numMostrar = aux;
      aux+=1;
    }
   });
 }

}
