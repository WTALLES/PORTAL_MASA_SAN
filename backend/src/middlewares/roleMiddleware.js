module.exports = function requireRole(...allowedRoles) {
  return (req, res, next) => {
    const role = req.admin?.role;
    if (!role || !allowedRoles.includes(role)) {
      return res.status(403).json({ error: 'Acesso negado: Perfil sem permissão para esta área.' });
    }
    
    next();
  };
};
