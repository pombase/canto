$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
    });
    if ($(this).is(".undisclosed-title")) {
      $(this).next().hide();
    } else {
      $(this).next().show();
    }
  })
});

$(function() {
  var ontology_complete_url = application_root + '/ws/lookup/go/component/term/';

  var term_selected = function() {
    var term_id = $('#ontology-term-id').val();
    if (term_id) {
      $.ajax({
        url: ontology_complete_url,
        data: { term: term_id, def: 1 },
        dataType: 'json',
        success: function (data) {
          $('#ontology-term-definition').text(data[0].definition);
        }
      });
    }
  }

  $( "#ontology-term-entry" ).autocomplete({
    minLength: 2,
    source: ontology_complete_url,
    focus: function(event, ui) {
      $('#ontology-term-entry').val(ui.item.name);
      return false;
    },
    select: function(event, ui) {
      $('#ontology-term-id').val(ui.item.id);
      $('#ontology-term-entry').val(ui.item.name);
      return false;
    },
    close: term_selected
  })
  .data( "autocomplete" )._renderItem = function( ul, item ) {
    return $( "<li></li>" )
      .data( "item.autocomplete", item )
      .append( "<a>" + item.id + "<br>" + item.name + "</a>" )
      .appendTo( ul );
  };
});

