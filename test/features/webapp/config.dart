//Configuration
part of features;

//URI mapping
var _uriMapping = {
  "/forward": forward,
  "/include": includerView  //generated from includerView.rsp.html
};

//Error mapping
var _errMapping = [
  [404, "/404.html"]
];