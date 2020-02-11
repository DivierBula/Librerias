using System;
using System.Collections.Generic;
using System.Linq;

namespace CT.Common.Utilities
{
    public static class ExtencionesBasicas
    {
        public static List<IT> CastToList<T, IT>(this IEnumerable<T> lista) where T : IT
        {
            return lista.IsNullOrEmpty<T>() ? (!lista.IsNull() ? new List<IT>() : (List<IT>)null) : lista.Cast<IT>().ToList<IT>();
        }

        public static bool IsNull(this object objeto)
        {
            return objeto == null || objeto is DBNull;
        }

        public static bool IsCero(this int numero)
        {
            return numero == 0;
        }

        public static bool IsNotNull(this object objeto)
        {
            return !objeto.IsNull();
        }

        public static bool IsValid(this DateTime fecha)
        {
            return !fecha.IsNull() && fecha > DateTime.MinValue && fecha < DateTime.MaxValue;
        }

        public static bool IsNullOrEmpty(this string cadena)
        {
            return string.IsNullOrEmpty(cadena);
        }

        public static bool IsValidaDate(this string date)
        {
            DateTime result;
            return DateTime.TryParse(date, out result);
        }

        public static bool IsNullOrEmpty(this Guid guid)
        {
            return guid.IsNull() || guid == Guid.Empty;
        }

        public static bool IsNullOrEmpty<T>(this IEnumerable<T> lista)
        {
            return lista.IsNull() || !lista.Any<T>();
        }
        
        public static List<TR> ListMapper<T, TR>(this List<T> estaLista, Func<T, TR> entityMapper) where TR : class
        {
            return estaLista.CollectionMapper<T, TR, List<TR>>(entityMapper);
        }
        
        private static TL CollectionMapper<T, TR, TL>(this List<T> estaLista, Func<T, TR> entityMapper) where TR : class where TL : ICollection<TR>, new()
        {
            TL retorno;
            if (!estaLista.IsNull())
            {
                retorno = new TL();
                if (!estaLista.IsNullOrEmpty<T>())
                    estaLista.ForEach((Action<T>)(item => retorno.Add(entityMapper(item))));
            }
            else
                retorno = default(TL);
            return retorno;
        }
        
    }
}
