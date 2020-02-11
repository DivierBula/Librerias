using System;


namespace CT.Common.Utilities
{
    public class StringValueAttribute : System.Attribute
    {
        private string _value;
        public StringValueAttribute(string value) { _value = value; }
        public string Value { get { return _value; } }
    }

    public static class ExtensionEnum
    {
        public static string ToStringAttribute(this Enum value)
        {
            System.Collections.Hashtable _stringValues = new System.Collections.Hashtable();

            string output = null;
            Type type = value.GetType();

            if (_stringValues.ContainsKey(value))
                output = (_stringValues[value] as StringValueAttribute).Value;
            else
            {
                System.Reflection.FieldInfo fi = type.GetField(value.ToString());
                StringValueAttribute[] atributos = fi.GetCustomAttributes(typeof(StringValueAttribute), false) as StringValueAttribute[];
                if (atributos.Length > 0)
                {
                    _stringValues.Add(value, atributos[0]);
                    output = atributos[0].Value;
                }
            }
            return output;
        }
    }
}
