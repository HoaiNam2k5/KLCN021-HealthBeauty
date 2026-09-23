using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class VaitroQuyen
{
    public int VaiTroId { get; set; }

    public int QuyenId { get; set; }

    public bool DuocCap { get; set; }

    public DateTime NgayGan { get; set; }

    public virtual Quyen Quyen { get; set; } = null!;

    public virtual Vaitro VaiTro { get; set; } = null!;
}
