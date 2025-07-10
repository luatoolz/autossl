return setmetatable({},{
__index=function(self, k)
  if type(k)~='string' then error('invalid key type') end
  if k=='' then error('empty key') end
  local rv = os.getenv(string.upper(k))
  if rv and rv~='' then return rv else return nil end
end
})
