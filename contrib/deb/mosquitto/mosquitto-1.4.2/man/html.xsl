<!-- Set parameters for manpage xsl -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:import href="/usr/share/xml/docbook/stylesheet/docbook-xsl/html/docbook.xsl"/>
	<xsl:output encoding="utf-8" indent="yes"/>
	<xsl:param name="html.stylesheet">man.css</xsl:param>
	<!-- Generate ansi style function synopses. -->
	<xsl:param name="man.funcsynopsis.style">ansi</xsl:param>
	<xsl:param name="make.clean.html" select="1"></xsl:param>
	<xsl:param name="make.valid.html" select="1"></xsl:param>
	<xsl:param name="html.cleanup" select="1"></xsl:param>
	<xsl:param name="docbook.css.source"></xsl:param>


	<xsl:template match="*" mode="process.root">
		<xsl:variable name="doc" select="self::*"/>

		<xsl:call-template name="user.preroot"/>
		<xsl:call-template name="root.messages"/>

		<xsl:text disable-output-escaping="yes"><![CDATA[<?php include '../_includes/header.php' ?>]]></xsl:text>
			<xsl:call-template name="body.attributes"/>
			<xsl:call-template name="user.header.content">
				<xsl:with-param name="node" select="$doc"/>
			</xsl:call-template>
			<xsl:apply-templates select="."/>
			<xsl:call-template name="user.footer.content">
				<xsl:with-param name="node" select="$doc"/>
			</xsl:call-template>
		<xsl:text disable-output-escaping="yes"><![CDATA[<?php include '../_includes/footer.php' ?>]]></xsl:text>
	
		<!-- Generate any css files only once, not once per chunk -->
		<xsl:call-template name="generate.css.files"/>
	</xsl:template>
</xsl:stylesheet>
