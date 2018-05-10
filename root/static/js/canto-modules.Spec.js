
describe('canto-modules.js', function() {

  var $controller, $scope, $q;
  var deferred;
  var ui_bootstrap, angular_confirm, toaster, chartJs;

  beforeEach(function(){
    module('cantoApp', function($provide){
      $provide.value('ui.bootstrap', 'angular-confirm', 'toaster', 'chart.js', {
        ui_bootstrap: jasmine.createSpy('ui.bootstrap'),
        angular_confirm: jasmine.createSpy('angular-confirm'),
        toastr: jasmine.createSpy('toastr'),
        chartJs: jasmine.createSpy('chart.js')
      });
    });
  });

  afterAll(function(){
    ui_bootstrap = null;
    angular_confirm = null;
    toaster = null;
    chartJs = null;
  });
  describe('Module functions', function() {
    it('should return a string when the first letter capitalized when capitalizeFirstLetter() called', function() {
      expect(capitalizeFirstLetter('hello')).not.toEqual('hello');
      expect(capitalizeFirstLetter('hello')).toEqual('Hello');
      expect(capitalizeFirstLetter('hello')).toEqual(jasmine.any(String));
      expect(capitalizeFirstLetter('hEllo')).toEqual('HEllo');
      expect(capitalizeFirstLetter('')).toEqual('');
    });

    it('should return a number of keys passed into countKeys() function', function() {
      var testKeys = {
        a: "a value",
        b: "another value",
        c: "last value",
      }

      expect(countKeys(testKeys)).toEqual(3);
      expect(countKeys(testKeys)).toEqual(jasmine.any(Number));
      expect(countKeys(testKeys)).not.toEqual(0);
    });

    it('should return an array not containing removed item when arrayRemoveOne() called', function() {
      var testArray = ['orange', 'apple', 'plumb', 'cat'];
      var testArrayOrig = testArray;

      arrayRemoveOne(testArray, 'apple');

      expect(testArray.length).toEqual(3);
      expect(testArray.indexOf('apple')).toEqual(-1);
      expect(testArray).toEqual(jasmine.any(Array));
    });

    it('should make a copy of object when copyObject() called', function() {
      var testObj = {
        a: "a value",
        b: "another value",
        someData: ['orange', 'apple', 'plumb', 'cat'],
        c: "last value",
      }

      var testObjCopy = {};

      copyObject(testObj, testObjCopy);

      expect(countKeys(testObjCopy)).toEqual(4);
      expect(testObjCopy.a).toEqual('a value');
      expect(testObjCopy.b).toEqual('another value');
      expect(testObjCopy.c).toEqual('last value');
      expect(testObjCopy.someData).toEqual(jasmine.any(Array));
    });

    it('should make a filtered copy of object when copyObject() called', function() {
      var testObj = {
        a: "a value",
        b: "another value",
        someData: ['orange', 'apple', 'plumb', 'cat'],
        c: "last value",
      }

      var keysFilter = {
        someData: true
      };

      var testObjCopy = {};

      copyObject(testObj, testObjCopy, keysFilter);

      expect(countKeys(testObjCopy)).toEqual(1);
      expect(testObjCopy.someData).toEqual(jasmine.any(Array));
      expect(testObjCopy.a).toBeFalsy();
      expect(testObjCopy.b).toBeFalsy();
      expect(testObjCopy.c).toBeFalsy();
    });

    it('should make a copy of object when copyObject() called without angular keys ($$)', function() {
      var testObj = {
        a: "a value",
        b: "another value",
        $$observers: ['ng', 'ngMock', 'cantoApp'],
        someData: ['orange', 'apple', 'plumb', 'cat'],
        c: "last value",
      }

      var testObjCopy = {};

      copyObject(testObj, testObjCopy);

      expect(countKeys(testObjCopy)).toEqual(4);
      expect(testObjCopy.a).toEqual('a value');
      expect(testObjCopy.b).toEqual('another value');
      expect(testObjCopy.c).toEqual('last value');
      expect(testObjCopy.someData).toEqual(jasmine.any(Array));
    });

  });
});