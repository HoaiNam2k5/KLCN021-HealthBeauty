/* Add missing grants required by API fixes; preserve explicit revocations. */
USE [KLCN021_HealthBeauty];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
INSERT dbo.VAITRO_QUYEN (VaiTroID, QuyenID, DuocCap)
SELECT role.VaiTroID, permission.QuyenID, 1
FROM dbo.VAITRO role
JOIN (VALUES
    (N'Reception','CUSTOMER.WRITE'), (N'Reception','STAFF.READ'), (N'Reception','INVOICE.WRITE'),
    (N'Staff','STAFF.READ')
) required(RoleName, PermissionCode) ON required.RoleName = role.TenVaiTro
JOIN dbo.QUYEN permission ON permission.MaQuyen = required.PermissionCode
WHERE NOT EXISTS (SELECT 1 FROM dbo.VAITRO_QUYEN existing
    WHERE existing.VaiTroID = role.VaiTroID AND existing.QuyenID = permission.QuyenID);
COMMIT TRANSACTION;
