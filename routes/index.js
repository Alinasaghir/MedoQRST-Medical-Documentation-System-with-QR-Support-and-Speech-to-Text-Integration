const { json } = require('express');
var express = require('express');
var router = express.Router();
const sql = require("../dboperation");

router.get("/", function (req, res, next) {
  sql.getdata_withQuery().then((result) => {
    res.json(result);
  });
});


module.exports = router;
