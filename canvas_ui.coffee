# Polyhédronisme
#===================================================================================================
#
# A toy for constructing and manipulating polyhedra and other meshes
#
# Includes implementation of the conway polyhedral operators derived
# from code by mathematician and mathematical sculptor
# George W. Hart http://www.georgehart.com/
#
# Copyright 2011, Anselm Levskaya
# Released under the MIT License


# GLOBALS
#===================================================================================================
ctx={} # for global access to canvas context
CANVAS_WIDTH  = 500 #canvas dims
CANVAS_HEIGHT = 400 #canvas dims
globPolys={} # constructed polyhedras

globRotM = clone eye3
globlastRotM = clone eye3
#globtheta = 0 # rotation and projective mapping parameters
#globphi   = 0
perspective_scale = 800
persp_z_max = 5
persp_z_min = 0
persp_ratio = 0.8
_2d_x_offset = CANVAS_WIDTH/2 #300
_2d_y_offset = CANVAS_HEIGHT/2 #140

globtime = new Date() # for animation

BG_CLEAR = true # clear background or colored?
BG_COLOR = "rgba(255,255,255,1.0)" # background color
COLOR_METHOD = "area"
PaintMode = "fillstroke"
ctx_linewidth = 0.5 # for outline of faces

# Mouse Event Variables
MOUSEDOWN=false
LastMouseX=0
LastMouseY=0
LastSphVec=[1,0,0] #for 3d trackball

# random grabbag of polyhedra
DEFAULT_RECIPES = ["C2dakD","oC20kkkT","kn4C40A0dA4","opD","lT","lK5oC","knD","dn6x4K5bT","oox4P7","n18n18n9n9n9soxY9"]

# File-saving objects used to export txt/canvas-png
saveText = (text, filename) ->
  BB = window.BlobBuilder || window.WebKitBlobBuilder || window.MozBlobBuilder
  bb = new BB()
  bb.append(text)
  saveAs(bb.getBlob("text/plain;charset="+document.characterSet), filename)

# debug vars
old_centers=[]
old_normals=[]

# Polyhedra Coloring Functions
#===================================================================================================

def_palette  = ["#ff3333","#33ff33","#3333ff","#ffff33","#ff33ff","#33ffff","#dddddd","#555555","#dd0000","#00dd00","#0000dd"]
rwb_palette  = ["#ff8888","#dddddd","#777777","#aa3333","#ff0000","#ffffff","#aaaaaa"]
rwbg_palette = ["#ff8888","#ffeeee","#88ff88","#dd7777","#ff2222","#22ff22","#ee4422","#aaaaaa"]

# converts #xxxxxx / #xxx format into list of [r,g,b] floats
hextofloats = (hexstr)->
  if hexstr[0] is "#"
    hexstr = hexstr[1..]
  if hexstr.length is 3
    rgb = hexstr.split('').map(       (c)->parseInt(c+c, 16)/255 )
  else
    rgb = hexstr.match(/.{2}/g).map(  (c)->parseInt(c, 16)/255 )
  rgb

PALETTE = rwb_palette
palette = (n) -> if n < PALETTE.length then hextofloats(PALETTE[n]) else hextofloats(PALETTE[PALETTE.length-1])

#memoized color assignment to faces of similar areas
colorassign = (ar, colormemory) ->
  hash = round(100*ar)
  if hash of colormemory
    return colormemory[hash]
  else
    fclr = palette _.toArray(colormemory).length
    colormemory[hash] = fclr
    return fclr

paintPolyhedron = (poly) ->
  # Color the faces of the polyhedra for display
  poly.face_colors = []
  colormemory={}
  for f in poly.face
    if COLOR_METHOD is "area"
      # color by face area (quick proxy for different kinds of faces) convexarea
      face_verts = (poly.xyz[v] for v in f)
      clr = colorassign(convexarea(face_verts), colormemory)
    else
      # color by face-sidedness
      clr = palette f.length-3

    poly.face_colors.push clr

  poly


#===================================================================================================
# Parser Routines
#===================================================================================================

specreplacements = [
  [/e/g, "aa"],   # e --> aa   (abbr. for explode)
  [/b/g, "ta"],   # b --> ta   (abbr. for bevel)
  [/o/g, "jj"],   # o --> jj   (abbr. for ortho)
  [/m/g, "kj"],   # m --> kj   (abbr. for meta)
  [/t(\d*)/g, "dk$1d"],  # t(n) --> dk(n)d  (dual operations)
  [/j/g, "dad"],  # j --> dad  (dual operations)
  [/s/g, "dgd"],  # s --> dgd  (dual operations)
  [/dd/g, ""],    # dd --> null  (order 2)
  [/ad/g, "a"],   # ad --> a   (a_ = ad_)
  [/gd/g, "g"],   # gd --> g   (g_ = gd_)
  [/aO/g, "aC"],  # aO --> aC  (for uniqueness)
  [/aI/g, "aD"],  # aI --> aD  (for uniqueness)
  [/gO/g, "gC"],  # gO --> gC  (for uniqueness)
  [/gI/g, "gD"]]  # gI --> gD  (for uniqueness)

getOps = (notation) ->
  expanded = notation
  for [orig,equiv] in specreplacements
    expanded = expanded.replace(orig,equiv)
  console.log "#{notation} executed as #{expanded}"
  expanded

# create polyhedron from notation
generatePoly = (notation) ->
  poly = new polyhedron()
  n=0

  ops = getOps(notation)
  if ops.search(/([0-9]+)$/) != -1
    n = 1 * RegExp.lastParen
    ops = ops.slice(0, -RegExp.lastParen.length)

  switch ops.slice(-1)
    when "T" then poly = tetrahedron()
    when "O" then poly = octahedron()
    when "C" then poly = cube()
    when "I" then poly = icosahedron()
    when "D" then poly = dodecahedron()
    when "P" then poly = prism(n)
    when "A" then poly = antiprism(n)
    when "Y" then poly = pyramid(n)
    else return

  while ops != ""
    n=0
    if ops.search(/([0-9]+)$/) != -1
      n = 1 * RegExp.lastParen
      ops = ops.slice(0, -RegExp.lastParen.length)
    switch ops.slice(-1)
      # geometrical operators
      when "d" then poly     = dual(poly)
      when "k" then poly     = kisN(poly, n)
      when "a" then poly     = ambo(poly)
      when "g" then poly     = gyro(poly)
      when "p" then poly     = propellor(poly)
      when "r" then poly     = reflect(poly)
      # canonicalization operators
      when "K" then poly.xyz = canonicalXYZ(poly, if n is 0 then 1 else n)
      when "C" then poly.xyz = canonicalize(poly, if n is 0 then 1 else n)
      when "A" then poly.xyz =    adjustXYZ(poly, if n is 0 then 1 else n)
      # experimental
      when "n" then poly     = insetN(poly, n)
      when "x" then poly     = extrudeN(poly, n)
      when "l" then poly     = stellaN(poly, n)
      when "z" then poly     = triangulate(poly,false)

    ops = ops.slice(0,-1);  # remove last character

  # Recenter polyhedra at origin (rarely needed)
  poly.xyz = recenter(poly.xyz, poly.getEdges())
  poly.xyz = rescale(poly.xyz)

  # Color the faces of the polyhedra for display
  poly = paintPolyhedron(poly)

  # return the poly object
  poly


# parses URL string for polyhedron recipe, for bookmarking
# should use #! href format instead
parseurl = () ->
  urlParams = {}
  a = /\+/g  # Regex for replacing addition symbol with a space
  r = /([^&=]+)=?([^&]*)/g
  d = (s) -> decodeURIComponent(s.replace(a, " "))
  q = window.location.search.substring(1)

  while e=r.exec(q)
    urlParams[d(e[1])] = d(e[2])
  urlParams



#===================================================================================================
# Drawing Functions
#===================================================================================================

# init canvas element
# -------------------------------------------------------------------------------
init = ->
  canvas = $('#poly')
  canvas.width(CANVAS_WIDTH)
  canvas.height(CANVAS_HEIGHT)

  ctx = canvas[0].getContext("2d")
  ctx.lineWidth = ctx_linewidth

  if BG_CLEAR
    ctx.clearRect 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT
  else
    ctx.clearRect 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT
    ctx.fillStyle = BG_COLOR
    ctx.fillRect 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT

# clear canvas
# -----------------------------------------------------------------------------------
clear = ->
  if BG_CLEAR
    ctx.clearRect 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT
  else
    ctx.clearRect 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT
    ctx.fillStyle = BG_COLOR
    ctx.fillRect 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT

# z sorts faces of poly
# -------------------------------------------------------------------------
sortfaces = (poly) ->
  #smallestZ = (x) -> _.sortBy(x,(a,b)->a[2]-b[2])[0]
  #closests = (smallestZ(poly.xyz[v] for v in f) for f in poly.face)
  centroids  = poly.centers()
  normals    = poly.normals()
  ray_origin = [0,0, (persp_z_max * persp_ratio - persp_z_min)/(1-persp_ratio)]
  #console.log ray_origin

  # sort by binary-space partition: are you on same side as view-origin or not?
  # !!! there is something wrong with this. even triangulated surfaces have artifacts.
  planesort = (a,b)->
    #console.log dot(sub(ray_origin,a[0]),a[1]), dot(sub(b[0],a[0]),a[1])
    -dot(sub(ray_origin,a[0]),a[1])*dot(sub(b[0],a[0]),a[1])

  # sort by centroid z-depth: not correct but more stable heuristic w. weird non-planar "polygons"
  zcentroidsort = (a,b)->
    a[0][2]-b[0][2]

  zsortIndex = _.zip(centroids, normals, [0..poly.face.length-1])
    #.sort(planesort)
    .sort(zcentroidsort)
    .map((x)->x[2])

  # sort all face-associated properties
  poly.face = (poly.face[idx] for idx in zsortIndex)
  poly.face_colors = (poly.face_colors[idx] for idx in zsortIndex)


# main drawing routine for polyhedra
#===================================================================================================
drawpoly = (poly,tvec) ->
  tvec ||= [3,3,3]

  # rotate poly in 3d
  oldxyz = _.map(poly.xyz, (x)->x)
  #poly.xyz = _.map(poly.xyz, (x)->mv3(rotm(rot[0],rot[1],rot[2]),x))
  poly.xyz = _.map(poly.xyz, (x)->mv3(globRotM,x))

  # z sort faces
  sortfaces(poly)

  for [fno,face] in enumerate(poly.face)
    ctx.beginPath()
    # move to first vertex of face
    v0 = face[face.length-1]
    [x,y] = perspT(add(tvec,poly.xyz[v0]), persp_z_max,persp_z_min,persp_ratio,perspective_scale)
    ctx.moveTo(x+_2d_x_offset, y+_2d_y_offset)
    # loop around face, defining polygon
    for v in face
      [x,y] = perspT(add(tvec,poly.xyz[v]),persp_z_max,persp_z_min,persp_ratio,perspective_scale)
      ctx.lineTo(x+_2d_x_offset, y+_2d_y_offset)

    # use pre-computed colors
    clr = poly.face_colors[fno]

    # shade based on simple cosine illumination factor
    face_verts = (poly.xyz[v] for v in face)
    illum = dot(normal(face_verts), unit([1,-1,0]))
    clr   = mult((illum/2.0+.5)*0.7+0.3,clr)

    #console.log dot(normal(face_verts), calcCentroid(face_verts))
    #  clr = "rgba(0,0,0,1)"

    if PaintMode is "fill" or PaintMode is "fillstroke"
      ctx.fillStyle   = "rgba(#{round(clr[0]*255)}, #{round(clr[1]*255)}, #{round(clr[2]*255)}, #{1.0})"
      ctx.fill()
    # make cartoon stroke (=black) / realistic stroke an option (=below)
      ctx.strokeStyle = "rgba(#{round(clr[0]*255)}, #{round(clr[1]*255)}, #{round(clr[2]*255)}, #{1.0})"
      ctx.stroke()
    if PaintMode is "fillstroke"
      ctx.fillStyle   = "rgba(#{round(clr[0]*255)}, #{round(clr[1]*255)}, #{round(clr[2]*255)}, #{1.0})"
      ctx.fill()
      ctx.strokeStyle = "rgba(0,0,0, .3)"  # light lines, less cartoony, more render-y
      ctx.stroke()
    if PaintMode is "stroke"
      ctx.strokeStyle = "rgba(0,0,0, .8)"
      ctx.stroke()

  #plot face-numbers and normal-vectors for debugging --------------------------------------------
  centers  = _.map( old_centers, (x)->mv3(globRotM,x))
  normals  = _.map( old_normals, (x)->mv3(globRotM,x))
  face_labels = ("#{fno}" for fno in [0..centers.length-1])
  vert_labels = ("#{vno}" for vno in [0..poly.xyz.length-1])
  for [fno,face] in enumerate(poly.face) # original, unsorted face_indices
    ctx.textAlign = "center"
    ctx.fillStyle = "rgba(0,0,0,1)"
    [x,y] = perspT(add(tvec, centers[fno]),persp_z_max,persp_z_min,persp_ratio,perspective_scale)
    ctx.fillText(face_labels[fno],x+_2d_x_offset,y+_2d_y_offset)
  for [fno,face] in enumerate(poly.face) # face normals
    ctx.strokeStyle = "rgba(0,0,0,1)"
    ctx.beginPath()
    [x,y] = perspT(add(tvec, centers[fno]),persp_z_max,persp_z_min,persp_ratio,perspective_scale)
    ctx.moveTo(x+_2d_x_offset,y+_2d_y_offset)
    [x,y] = perspT(add(tvec, add(centers[fno],mult(0.1,normals[fno]))),persp_z_max,persp_z_min,persp_ratio,perspective_scale)
    ctx.lineTo(x+_2d_x_offset,y+_2d_y_offset)
    ctx.stroke()
  for [vno,vert] in enumerate(poly.xyz) # vertex indices
    [x,y] = perspT(add(tvec, poly.xyz[vno]),persp_z_max,persp_z_min,persp_ratio,perspective_scale)
    #ctx.fillText(vert_labels[vno],x+_2d_x_offset,y+_2d_y_offset)
  #-----------------------------------------------------------------------------------------------

  # reset coords, for setting absolute rotation, as poly is passed by ref
  poly.xyz = oldxyz


# draw polyhedra just once
# -----------------------------------------------------------------------------------
drawShape = ->
  clear()
  for [i,p] in enumerate(globPolys)
    drawpoly(p,[0+3*i,0,3])


# loop for animation
# -----------------------------------------------------------------------------------
animateShape = ->
  clear()
  globtheta=(2*Math.PI)/180.0*globtime.getSeconds()*0.1
  for [i,p] in enumerate(globPolys)
    drawpoly(p,[0+3*i,0,3])
  setTimeout(animateShape, 100)


# Initialization and Basic UI
#===================================================================================================

$( -> #wait for page to load

  init() #init canvas

  urlParams = parseurl() #see if recipe is spec'd in URL
  if "recipe" of urlParams
    specs=[urlParams["recipe"]]
    $("#spec").val(specs)
  else
    specs=[randomchoice(DEFAULT_RECIPES)]
    $("#spec").val(specs)

  # construct the polyhedra from spec
  #globPolys = _.map(specs, (x)->generatePoly(x))

  c0 = cube()
  c1 = cube()
  c2 = cube().rescale(.5)
  for v in c0.xyz
    #c2.xyz = _.map(c2.xyz, (x)->[x[0]+v[0]/2,x[1]+v[1]/2,x[2]+v[2]/2] )
    c2.translate(mult(1,v))
    c1 = csgUnion(c1, c2)
    c2.translate(mult(-1,v))
  #console.log c3
  c4 = c1
  #c4.xyz = canonicalize(c4,10)
  globPolys = [paintPolyhedron(c4)]

  #c1 = cube()
  #c2 = cube()
  #c2.xyz = _.map(c2.xyz, (x)-> mv3(rotm(PI/3,PI/3,0),x) )
  #c3 = cube()
  #c3.xyz = _.map(c3.xyz, (x)-> mv3(rotm(2*PI/3,2*PI/3,0),x) )
  #c4 = csgUnion(c3,csgUnion(c1,c2))
  #console.log c4
  #globPolys = [paintPolyhedron(ambo c4)]

  #console.log "face count from " , c4.face.length, "to", uniteFaces(c4).face.length, "should be", 6*8+6

  old_centers = _.map(globPolys[0].centers(),(x)->x)
  old_normals = _.map(globPolys[0].normals(),(x)->x)

  #globPolys = [paintPolyhedron(uniteFaces(c4))]


  # draw it
  drawShape()
  try
    uniteFaces(clone c4)

  # Event Handlers
  # ----------------------------------------------------

  # when spec changes in input, parse and draw new polyhedra
  $("#spec").change((e) ->
    specs = $("#spec").val().split(/\s+/g)[0..1] #only allow one recipe for now
    globPolys = _.map(specs, (x)->generatePoly(x) )
    #animateShape()
    #window.location.replace("?recipe="+specs[0])
    drawShape()
  )

  # Basic manipulation: rotation and scaling of geometry
  # ----------------------------------------------------

  # mousewheel changes scale of drawing
  $("#poly").mousewheel( (e,delta, deltaX, deltaY)->
    e.preventDefault()
    perspective_scale*=(10+delta)/10
    drawShape()
  )

  # Implement standard trackball routines
  # ---------------------------------------
  $("#poly").mousedown( (e)->
    e.preventDefault()
    MOUSEDOWN=true
    LastMouseX=e.clientX-$(this).offset().left #relative mouse coords
    LastMouseY=e.clientY-$(this).offset().top

    #calculate inverse projection of point to sphere
    tmpvec=invperspT(LastMouseX,LastMouseY,_2d_x_offset,_2d_y_offset,persp_z_max,persp_z_min,persp_ratio,perspective_scale)
    if tmpvec[0]*tmpvec[1]*tmpvec[2]*0 is 0  #quick NaN check
      LastSphVec=tmpvec
    globlastRotM = clone globRotM #copy last transform state
    #console.log LastSphVec[0],LastSphVec[1],LastSphVec[2]
  )
  $("#poly").mouseup( (e)->
    e.preventDefault()
    MOUSEDOWN=false
  )
  $("#poly").mouseleave( (e)->
    e.preventDefault()
    MOUSEDOWN=false
  )
  $("#poly").mousemove( (e)->
    e.preventDefault()
    if MOUSEDOWN
      MouseX=e.clientX-$(this).offset().left
      MouseY=e.clientY-$(this).offset().top
      SphVec=invperspT(MouseX,MouseY,_2d_x_offset,_2d_y_offset,persp_z_max,persp_z_min,persp_ratio,perspective_scale)

      # quick NaN check
      if SphVec[0]*SphVec[1]*SphVec[2]*0 is 0 and LastSphVec[0]*LastSphVec[1]*LastSphVec[2]*0 is 0
        globRotM = mm3(getVec2VecRotM(LastSphVec,SphVec),globlastRotM)

      drawShape()
  )

  # State control via some buttons
  # ---------------------------------------

  $("#strokeonly").click((e) ->
    PaintMode = "stroke"
    drawShape()
  )
  $("#fillonly").click((e) ->
    PaintMode = "fill"
    drawShape()
  )
  $("#fillandstroke").click((e) ->
    PaintMode = "fillstroke"
    drawShape()
  )

  $("#siderot").click((e) ->
    globRotM = vec_rotm(PI/2,0,1,0)
    drawShape()
  )
  $("#toprot").click((e) ->
    globRotM = vec_rotm(PI/2,1,0,0)
    drawShape()
  )
  $("#frontrot").click((e) ->
    globRotM = rotm(0,0,0)
    drawShape()
  )

  # Export Options
  # ---------------------------------------

  $("#pngsavebutton").click((e)->
    canvas=$("#poly")[0]
    #this works, but is janky
    #window.location = canvas.toDataURL("image/png")
    spec = $("#spec").val().split(/\s+/g)[0]
    filename = "polyhedronisme-"+spec+".png"
    canvas.toBlob( (blob)->saveAs(blob, filename) )
  )
  $("#objsavebutton").click((e)->
    objtxt = globPolys[0].toOBJ()
    spec = $("#spec").val().split(/\s+/g)[0]
    filename = "polyhedronisme-"+spec+".obj"
    saveText(objtxt,filename)
  )
  $("#x3dsavebutton").click((e)->
    triangulated = triangulate(globPolys[0],true) #triangulate to preserve face_colors for 3d printing
    x3dtxt = triangulated.toVRML()
    spec = $("#spec").val().split(/\s+/g)[0]
    #filename = "polyhedronisme-"+spec+".x3d"
    filename = "polyhedronisme-"+spec+".wrl"
    saveText(x3dtxt,filename)
  )

)