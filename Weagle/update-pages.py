#!/usr/bin/env python

import os
from pywow import wdbc

def main():
	if os.path.exists("Pages.lua.bak"):
		f = open("Pages.lua.bak", "r")
	else:
		f = open("Pages.lua", "r")
	out = f.read()
	f.close()
	os.rename("Pages.lua", "Pages.lua.bak")
	
	db2 = wdbc.get("Item-sparse.db2", -1)
	out = out.replace("--[[__ITEM-SPARSE.DB2__]]", ",\n\t".join(str(k) for k in db2))
	
	f = open("Pages.lua", "w")
	f.write(out)
	f.close()

if __name__ == "__main__":
	main()
