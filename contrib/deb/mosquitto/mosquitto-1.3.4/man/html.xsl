<!-- Set parameters for manpage xsl -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:import href="/usr/share/xml/docbook/stylesheet/docbook-xsl/html/docbook.xsl"/>
	<xsl:param name="html.stylesheet">man.css</xsl:param>
	<!-- Generate ansi style function synopses. -->
	<xsl:param name="man.funcsynopsis.style">ansi</xsl:param>
</xsl:stylesheet>
