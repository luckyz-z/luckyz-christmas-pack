using System; using System.IO; using System.Linq; using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Media.Control; using Windows.Storage.Streams;
public static class ThlaArt {
  public static byte[] Get() {
    var mgr = GlobalSystemMediaTransportControlsSessionManager.RequestAsync().AsTask().Result;
    var s = mgr.GetSessions().FirstOrDefault(x => x.SourceAppUserModelId.ToLower().Contains("spotify"));
    if (s == null) return null;
    var p = s.TryGetMediaPropertiesAsync().AsTask().Result;
    if (p.Thumbnail == null) return null;
    using (var rs = p.Thumbnail.OpenReadAsync().AsTask().Result)
    using (var st = rs.AsStreamForRead())
    using (var ms = new MemoryStream()) { st.CopyTo(ms); return ms.ToArray(); }
  }
}
