# 初始化 restapi 服务

fs          = require "fs"
restify     = require "restify"
_           = require "underscore"
Router      = require "./router"
helper      = require "./helper"
defaultCtl  = require "./controller"
model       = require "./model"
utils       = require "./utils"
openrest    = require "../package"

# 根据设置的路径，获取对象
getModules = (_path) ->
  modules = {}
  for file in utils.readdir(_path, ['coffee', 'js'])
    moduleName = utils.file2Module file
    modules[moduleName] = require "#{_path}/#{file}"

  modules

# 检查参数的正确性
requiredCheck = (opts) ->

  # app路径检查
  unless opts.appPath
    throw Error 'Lack appPath: absolute path of your app'

  # 默认路径的处理，这里有一些路径上的约定
  _.each(['route', 'controller', 'model'], (_path) ->
    if pwd = opts["#{_path}Path"]
      unless _.isString pwd
        throw Error "#{_path}Path must be a string and be a existed path"
      unless fs.existsSync pwd
        throw Error "#{_path}Path must be a string and be a existed path"
    else
      opts["#{_path}Path"] = "#{opts.appPath}/#{_path}s"
  )

  # 中间件路径的处理
  unless opts.middleWarePath
    opts.middleWarePath = "#{opts.appPath}/middle-wares"

  # 路由设置路径的处理
  unless opts.routePath
    opts.routePath = "#{opts.appPath}/routes"

  # todo list 以后补上

# 根据传递进来的 opts 构建 restapi 服务
# opts = {
#   config: Object, // 配置项目
#   appPath: directory, // required 应用路径，绝对路径，这个非常重要，之后
#   routePath: directory, // optional 路由器配置路径，绝对路径
#                       // 的控制器路径，模型路径都可以根绝这个路径生成
#   controllerPath: directory // optional controllers 目录, 绝对路径,
#                             // 默认为 appPath + '/controllers/'
#   modelPath: directory // optional models 目录, 绝对路径,
#                        // 默认为 appPath + '/models/'
#   middleWarePath: directory // optional 用户自定义的中间件的路径，绝对路径
# }
#
module.exports = (opts) ->

  # required check
  requiredCheck(opts)

  # 初始化model，并且将models 传给initModels
  # 传进去的目的是为了后续通过 utils.model('modelName')来获取model
  model.init(opts.config.db, opts.modelPath or "#{opts.appPath}/models")

  # 创建web服务
  service = opts.config.service or openrest
  server = restify.createServer
    name: service.name
    version: service.version

  # 设置中间件
  server.use restify.acceptParser(server.acceptable)
  server.use restify.queryParser()
  server.use restify.bodyParser()
  server.use (req, res, next) ->
    # 初始化 hooks
    req.hooks = {}
    # 强制处理字符集
    res.charSet opts.config.charset or 'utf-8'
    next()

  # 自定义中间件
  # 需要自定义一些中间件，请写在这里
  if fs.existsSync(opts.middleWarePath)
    middleWares = require opts.middleWarePath
    if _.isArray middleWares
      server.use(middleWare) for middleWare in middleWares

  # 路由初始化、控制器载入
  require(opts.routePath) new Router(
    server
    getModules(opts.controllerPath or "#{opts.appPath}/controllers")
    defaultCtl
  )

  # 监听错误，打印出来，方便调试
  server.on 'uncaughtException', (req, res, route, error) ->
    console.error new Date
    console.error route
    console.error error
    res.send(500, 'Internal error')

  # 设置监听
  server.listen opts.config.service.port or 8080, ->
    console.log '%s listening at %s', server.name, server.url