using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Configuration;

namespace CT.Common.Utilities
{
    public class Log4Net
    {
        public void registrarLog(String msm, String metodo)
        {
            bool logActivo = Convert.ToBoolean(ConfigurationManager.AppSettings["Log"]);

            if (logActivo)
            {
                string path = @" C:\log4Net_Bibliotenca.txt";
                if (File.Exists(path))
                {
                    using (StreamWriter mylogs = File.AppendText(path))
                    {
                        DateTime dateTime = new DateTime();
                        dateTime = DateTime.Now;
                        string strDate = Convert.ToDateTime(dateTime).ToString("dd-mm-yyyy");
                        mylogs.WriteLine(msm +" "+ strDate);
                        mylogs.Close();
                    }
                }
                else
                {
                    using (FileStream fs = File.Create(path))
                    {
                        DateTime dateTime = new DateTime();
                        dateTime = DateTime.Now;
                        string strDate = Convert.ToDateTime(dateTime).ToString("dd-mm-yyyy");
                        Byte[] info = new UTF8Encoding(true).GetBytes(msm +" "+  strDate);
                        fs.Write(info, 0, info.Length);
                    }
                }
            }
        }
    }
}
